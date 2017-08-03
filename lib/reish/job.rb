#
#   job.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

module Reish

  class JobController
    def initialize(shell)
      @shell = shell

      @foreground_job = nil
      @jobs = []
    end

    attr_reader :jobs

    def shrink_jobs
      until @jobs.empty? || @jobs.last; @jobs.pop; end
    end

#     def fg(id=nil)
#       id = @jobs.size-1 unless id
#       job = @jobs[id]
#       @foreground_job = job
#       @jobs[id] = nil
#       shrink_jobs
#       job.to_foreground
#     end

#     def bg(id=nil)
#       id = @jobs.size-1 unless id
#       job = @jobs[id]
#       job.to_background
#     end

    def fgbg(fg = true, id=nil)
      id = @jobs.size-1 unless id
      job = @jobs[id]
      Reish.fail NoTargetJob
      if fg
	@foreground_job.instance_eval{@foreground=false} if @foreground_job
	@foreground_job = job
	@jobs[id] = nil
	shrink_jobs
      end
      job.to_fgbg(fg)
    end

#     def start_foreground_job(script=nil, &block)
#       job = Job.new(@shell)
#       job.source = script
#       @foreground_job = job
#       @foreground_job.start do
# 	begin
# 	  block.call
# 	ensure
# 	  finish_job(job)
# 	end
#       end
#     end

#     def start_background_job(script=nil, &block)
#       job = Job.new(@shell)
#       job.source = script
#       @jobs.push job
#       job.start(false) do
# 	begin
# 	  block.call
# 	ensure
# 	  finish_job(job)
# 	end
#       end
#     end

    def start_job(fg = true, script=nil, &block)
      job = Job.new(@shell)
      job.source = script
      if fg
	@foreground_job = job
      else
	@jobs.push job
      end
      job.start(fg) do
	begin
	  block.call
	ensure
	  finish_job(job)
	end
      end
      # fgでbackground-jobがforegroundになったときの待ちの処理
      @foreground_job.wait if fg && @foreground_job
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

    def initialize(term_ctl)
      @term_ctl = term_ctl

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

    def set_process_exit_stat(pid, stat, status)
      com = @processes[pid]
      unless com
	puts "ProcessMonitor: process id[#{pid}] no exist(stat = #{stat})" if Reish::debug_jobctl?
	return
      end
      com.set_exit_stat(stat, status)
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
#	Thread.abort_on_exception = true

	wait_flag = Process::WNOHANG|Process::WUNTRACED|Reish::WCONTINUED

	loop do
	  @monitor_queue.pop
	  
	  begin
	    loop do
	      pid, stat = Process.waitpid2(-1, wait_flag)
	      break unless pid
	  
	      case 
	      when stat.signaled?
		puts "ProcessMonitor: child #{stat.pid} was killed by signal #{stat.termsig}" if Reish::debug_jobctl?
		if stat.coredump?
		  puts "ProcessMonitor: child #{stat.pid} dumped core." if Reish::debug_jobctl?
		end

		set_process_exit_stat(pid, :TERM, stat)
		
	      when stat.stopped?
		puts "ProcessMonitor: child #{stat.pid} was stopped by signal #{stat.stopsig}" if Reish::debug_jobctl?
		case stat.stopsig
		when 20
		  set_process_stat(pid, :TSTP)
		  
		  MAIN_SHELL.reish_tstp(MAIN_SHELL) if @term_ctl
		  
		when 21
		  set_process_stat(pid, :TTIN)

		when 22
		  set_process_stat(pid, :TTOU)
		else
		  
		end

	      when stat.exited?
		puts "ProcessMonitor: child #{stat.pid} exited normally. status=#{stat.exitstatus}" if Reish::debug_jobctl?

		set_process_exit_stat(pid, :EXIT, stat)

	      when Reish::wifscontinued?(stat)
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

      @current_exe = nil
      @foreground = nil

      @thread = nil

      @wait_stat = nil
      @wait_mx = Mutex.new
      @wait_cv = ConditionVariable.new
    end
    attr_accessor :source

    def start(fg = true, &block)
      @foreground = fg

      @wait_stat = nil
      @thread = Thread.start {
	Thread.abort_on_exception = true
	Reish::current_job = self

	v = block.call

	@wait_mx.synchronize do
	  @wait_stat = true
	  @wait_cv.signal
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

#     def to_foreground
#       @foreground = true
#       job_cont
#       if @current_exe
# 	if @current_exe.pstat == :TSTP
# 	  #Reish.tcsetpgrp(STDOUT, @current_exe.pid)
# 	  set_ctlterm
# 	  Process.kill(:CONT, @current_exe.pid)
# 	end
#       end

#       @wait_stat = nil
#       wait
#     end

#     def to_background
#       @foreground = false
#       job_cont
#       if @wait_stat == :TSTP
# 	if @current_exe
# 	  if @current_exe.pstat == :TSTP
# 	    Process.kill(:CONT, @current_exe.pid)
# 	  end
# 	end
#       end
#     end

    def to_fgbg(fg=true)
      @foreground = fg
      job_cont
      if @current_exe
	set_ctlterm if @foreground
	Process.kill(:CONT, @current_exe.pid) if @current_exe.pstat == :TSTP
      end
#      if @foreground
#	wait
#      end
    end

    def wait
      @wait_mx.synchronize do
	while !@wait_stat
	  @wait_cv.wait(@wait_mx)
	end
	case @wait_stat
	when true
	  @thread.value
	when :TSTP
	  #Reish.tcsetpgrp(STDOUT, Process.pid)
	  reset_ctlterm 
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
      @wait_mx.synchronize do
	@wait_stat = :TSTP
	@wait_cv.signal
      end
    end

    def job_stop
      @thread.set_trace_func proc{Thread.stop}
    end

    def job_cont
      @wait_stat = nil
      @thread.set_trace_func nil
      @thread.run
    end

    def popen_process(exe, *opts, &block)
      @current_exe = exe
      begin
	opts[-1][:pgroup] = true if term_ctl?
	ProcessMonitor.Monitor.popen_process(exe, *opts) do |io|
	  #Reish.tcsetpgrp(STDOUT, io.pid) if @foreground
	  set_ctlterm if @foreground
	  block.call io
	end
      ensure
	#Reish.tcsetpgrp(STDOUT, Process.pid) if @foreground
	reset_ctlterm if @foreground
	@current_exe = nil
      end
    end

    def spawn_process(exe, *opts, &block)
      @current_exe = exe
      begin
	opts[-1][:pgroup] = true if term_ctl?
	ProcessMonitor.Monitor.spawn_process(exe, *opts) do
	  #Reish.tcsetpgrp(STDOUT, exe.pid) if @foreground
	  set_ctlterm if @foreground
	end
      ensure
	#Reish.tcsetpgrp(STDOUT, Process.pid) if @foreground
	reset_ctlterm if @foreground
	@current_exe = nil
      end
    end

    def set_ctlterm
      MAIN_SHELL.set_ctlterm(@current_exe.pid)
    end

    def reset_ctlterm
      MAIN_SHELL.set_ctlterm(nil)
    end

    def term_ctl?
      MAIN_SHELL.term_ctl?
    end

    def info
      if @current_exe
	"<#{@source}(#{@wait_stat && :RUN}) exe=#{@current_exe.info}>"
      else
	"<#{@source}(#{@wait_stat && :RUN})>"
      end
    end

    def inspect
      return super if Reish::INSPECT_LEBEL >= 3
      
      "#<Job: @current_exe=#{@current_exe.inspect}>"
    end
  end

  class CommandExecution
    def initialize(command)
      @command = command
      @job = Reish::current_job

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

    def set_exit_stat(stat, status)
      @wait_mx.synchronize do
	@pstat = stat
	@command.exit_status = status
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
	@command.exit_status = @exit_status
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

    def info
      "<#{@command.info}[#{@pid}](#{@pstat.id2name})>"
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
