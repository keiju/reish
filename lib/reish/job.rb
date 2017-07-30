#
#   job.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "ext/reish.so"

module Reish

  class JobController

    def self::start_background_job(script=nil, &block)
      sh = Reish::current_shell
      sh.job_controller.start_background_job(script) do
	sh.activate_command_search do
	  block.call
	end
      end
      nil
    end

    def self::current_job
      Thread.current[:__REISH_CURRENT_JOB__]
    end

    def self::current_job=(job)
      Thread.current[:__REISH_CURRENT_JOB__] = job
    end

    def initialize(shell)
      @shell = shell

      @foreground_job = nil
      @jobs = []
    end

    attr_reader :jobs

    def shrink_jobs
      until @jobs.empty? || @jobs.last; @jobs.pop; end
    end

    def fg(id=nil)
      id = @jobs.size-1 unless id
      job = @jobs[id]
      @foreground_job = job
      @jobs[id] = nil
      shrink_jobs
      job.to_foreground
    end

    def bg(id=nil)
      id = @jobs.size-1 unless id
      job = @jobs[id]
      job.to_background
    end

    def start_foreground_job(script=nil, &block)
      job = Job.new(@shell)
      job.source = script
      @foreground_job = job
      @foreground_job.start do
	begin
	  block.call
	ensure
	  finish_job(job)
	end
      end
    end

    def start_background_job(script=nil, &block)
      job = Job.new(@shell)
      job.source = script
      @jobs.push job
      job.start(false) do
	begin
	  block.call
	ensure
	  finish_job(job)
	end
      end
    end

    def finish_job(job)
      idx = @jobs.index(job)
      if idx
	@jobs[idx] = nil
	shrink_jobs
      end
    end

    def raise_foreground_job(*option)
      @foreground_job.throw_exception *option
    end

    def suspend_foreground_job
      job = @foreground_job
      @foreground_job = nil
      job.suspend
      @jobs.push job
    end
  end

  class ProcessMonitor

    def self.Monitor
      MAIN_SHELL.process_monitor
    end

    def initialize
      @processes = {}
      @processes_mx = Mutex.new

      @monitor = nil
      @monitor_queue = Queue.new

    end

    def add_process(com)
      @processes_mx.synchronize do
	@processes[com.pid] = com
      end
    end

    def del_process(com)
      @processes_mx.synchronize do
	@processes.delete(com)
      end
    end

    def set_process_stat(pid, stat)
      com = @processes[pid]
      unless com
	puts "ProcessMonitor: process id[#{pid}] no exist(stat = #{stat})" if Reish::debug_jobctl?
	return
      end
      com.pstat = stat
    end

    def popen_process(com, *opts, &block)
      IO.popen(*opts) do |io|
	com.pid = io.pid
	add_process(com)
	com.pstat = :RUN

	begin
	  block.call io
	ensure
	  com.wait
	  del_process(com)
	end
      end
    end

    def spawn_process(com, *opts, &block)
      pid = Process.spawn(*opts)
      begin
	com.pid = pid
	add_process(com)
	com.pstat = :RUN
	
	block.call

	com.wait
      ensure
	del_process(com)
      end
    end

    def start_monitor

# ruby's Bug#13768
      Thread.start do
	loop do
	  sleep 100
	end
      end

      @monitor = Thread.start{
	Thread.abort_on_exception = true

	loop do
	  @monitor_queue.pop
	  
	  begin
	    loop do
	      pid, stat = Process.waitpid2(-1, Process::WNOHANG|Process::WUNTRACED|Reish::WCONTINUED)
	      break unless pid
	  
	      case 
	      when stat.signaled?
		puts "ProcessMonitor: child #{stat.pid} was killed by signal #{stat.termsig}" if Reish::debug_jobctl?
		if stat.coredump?
		  puts "ProcessMonitor: child #{stat.pid} dumped core." if Reish::debug_jobctl?
		end

		set_process_stat(pid, :TERM)
		
	      when stat.stopped?
		puts "ProcessMonitor: child #{stat.pid} was stopped by signal #{stat.stopsig}" if Reish::debug_jobctl?
		case stat.stopsig
		when 20
		  set_process_stat(pid, :TSTP)
		  
#		  Reish.tcsetpgrp(STDOUT, Process.pid)
		  MAIN_SHELL.reish_tstp(MAIN_SHELL)
		  
		when 21
		  set_process_stat(pid, :TTIN)
		when 22
		  set_process_stat(pid, :TTOU)
		else
		  
		end

	      when stat.exited?
		puts "ProcessMonitor: child #{stat.pid} exited normally. status=#{stat.exitstatus}" if Reish::debug_jobctl?

		set_process_stat(pid, :EXIT)

	      when Reish::wifscontined?(stat)
		puts "ProcessMonitor: child #{stat.pid} continued." if Reish::debug_jobctl?
		set_process_stat(pid, :RUN)
	      else
		p "ProcessMonitor: Unknown status %#x" % stat.to_i if Reish::debug_jobctl?
	      end
	    end
	  rescue Errno::ECHILD
	    # ignore
	    puts "ProcessMonitor: #{$!}" if Reish::debug_jobctl?
	  end
	end
      }
    end

    def accept_sigchild
      @monitor_queue.push self
    end

  end

  class Job
    def initialize(shell)
      @shell = shell

      @source = nil

      @processes = []

      @foreground = nil

      @thread = nil
      @stat = nil
      @mx = Mutex.new
      @cv = ConditionVariable.new
    end
    attr_accessor :source

    def start(fg = true, &block)
      @foreground = fg

      @stat = nil
      @thread = Thread.start {
#	Thread.abort_on_exception = true
	JobController::current_job = self
	v = block.call
	@mx.synchronize do
	  @stat = true
	  @cv.signal
	end
	puts "FINISH background job(#{info})" unless @foreground
	v
      }

      if @foreground
	wait
      else
	# do nothing
      end 
    end

    def to_foreground
      @stat = nil
      @foreground = true
      job_cont
      for com in @processes do
	if com.pstat == :TSTP
	  Reish.tcsetpgrp(STDOUT, com.pid)
	  Process.kill(:CONT, com.pid)
	end
      end

      wait
    end

    def to_background
      @foreground = false
      job_cont
      if @stat == :TSTP
	for com in @processes do
	  if com.pstat == :TSTP
	    Process.kill(:CONT, com.pid)
	  end
	end
      end
    end

    def wait
      @mx.synchronize do
	while !@stat
	  @cv.wait(@mx)
	end
	case @stat
	when true
	  @thread.value
	when :TSTP
	  Reish.tcsetpgrp(STDOUT, Process.pid)
	  puts "suspend job"
	else
	  p s
	end
      end
    end

    def throw_exception(*option)
      @thread.raise *option
    end

    def suspend
      @foreground = false
      job_stop
      @mx.synchronize do
	@stat = :TSTP
	@cv.signal
      end
    end

    def job_stop
      @thread.set_trace_func proc{Thread.stop}
    end

    def job_cont
      @thread.set_trace_func nil
      @thread.run
    end

#    def start_backgorund_job(script)
#      
#    end

    def popen_process(com, *opts, &block)
      @processes.push com
      begin
	opts[-1][:pgroup] = true
	ProcessMonitor.Monitor.popen_process(com, *opts) do |io|
	  Reish.tcsetpgrp(STDOUT, io.pid) if @foreground
	  block.call io
	end
      ensure
	Reish.tcsetpgrp(STDOUT, Process.pid) if @foreground
	@processes.delete(com)
      end
    end

    def spawn_process(com, *opts, &block)
      @processes.push com
      begin
	opts[-1][:pgroup] = true
	ProcessMonitor.Monitor.spawn_process(com, *opts) do
	  Reish.tcsetpgrp(STDOUT, com.pid) if @foreground
	end
      ensure
	Reish.tcsetpgrp(STDOUT, Process.pid) if @foreground
	@processes.delete(com)
      end
    end

    def info
      "<#{@source} step=#{@processes.collect{|com| com.info}.join(" ")}>"
    end

    def inspect
      return super if Reish::INSPECT_LEBEL >= 3
      
      "#<Job: @processes=[#{@processes.collect{|com| com.inspect}.join(", ")}]>"
    end
  end

  class CommandExecution
    def initialize(command)
      @command = command
      @job = JobController.current_job

      @pid = nil
      @pstat = :NULL
      @exit_status = nil

      @wait_mx = Mutex.new
      @wait_cv = ConditionVariable.new
    end

    attr_accessor :pid
    attr_reader :pstat
    attr_reader :exit_status

    def pstat=(stat)
      @wait_mx.synchronize do
	@pstat = stat
	@wait_cv.broadcast
      end
    end

    def pstat_finish?
      @pstat == :EXIT || @pstat == :TERM
    end

    def popen(mode, &block)
      @job.popen_process(self, 
			 [@command.exenv.env, 
			   @command.command_path, 
			   *@command.command_opts], 
			 mode, 
			 @command.spawn_options, 
			 &block)
    end

    def spawn
      @job.spawn_process(self, 
			 @command.exenv.env, 
			 @command.command_path, 
			 *@command.command_opts,
			 @command.spawn_options)
    end

    def wait
      @wait_mx.synchronize do
	until pstat_finish?
	  @wait_cv.wait(@wait_mx)
	end
      end
    end

    def wait_while_closing(io)
      io.close
      @wait_mx.synchronize do
	unless $?
	  @command.exit_status = @exit_status
	  return
	end
	@exit_status = $?
	case 
	when @exit_status.signaled?
	  puts "CommandExecution: pid=#{@pid} was killed by signal #{@exit_status.termsig}" if Reish::debug_jobctl?
	  @pstat = :TERM
	when @exit_status.exited?
	  puts "CommandExecution: pid=#{@pid} exited normally. status=#{@exit_status.exitstatus}" if Reish::debug_jobctl?
	  @pstat = :EXIT
	end
	@wait_cv.broadcast
      end
    end
  end

  class ShellExecution<CommandExecution
    def popen(open_mode, &block)
      @job.popen_process(self,
			 @command.exenv.env, 
			 @command.to_script, 
			 open_mode, 
			 @command.spawn_options, 
			 &block)
    end


    def spawn
      @job.spawn_process(self,
			 @command.exenv.env, 
			 @command.to_script, 
			 @command.spawn_options)
    end
    
  end

end
