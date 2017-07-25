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

#    def bg(id=nil)
#
#    end

    def start_foreground_job(&block)
      job = Job.new(@shell)
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
      job.script = script
      @jobs.push job
      job.start(false) do
	begin
	  block.call
	ensure
	  puts "FINISH"
	  finish_job(job)
	  puts "FINISH END"
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
      @foreground_job.suspend
      @jobs.push @foreground_job
      @foreground_job = nil
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
	puts "ProcessMonitor: process id[#{pid}] no exist(stat = #{stat})"
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

    def spawn_process(com, *opts)
      pid = Process.spawn(*opts)
      begin
	com.pid = pid
	add_process(com)


	com.wait
      ensure
	del_process(com)
      end
    end

    def start_monitor

# ruby's bug?
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
		puts "ProcessMonitor: child #{stat.pid} was killed by signal #{stat.termsig}"
		if stat.coredump?
		  puts "ProcessMonitor: child #{stat.pid} dumped core."
		end

		set_process_stat(pid, :TERM)

	      when stat.stopped?
		puts "ProcessMonitor: child #{stat.pid} was stopped by signal #{stat.stopsig}"
		case stat.stopsig
		when 20
		  set_process_stat(pid, :TSTP)
		when 21
		  set_process_stat(pid, :TTIN)
		when 22
		  set_process_stat(pid, :TTOU)
		else
		  
		end

	      when stat.exited?
		puts "ProcessMonitor: child #{stat.pid} exited normally. status=#{stat.exitstatus}"

		p @process

		set_process_stat(pid, :EXIT)

	      when Reish::wifscontined?(stat)
		puts "ProcessMonitor: child #{stat.pid} continued."
		set_process_stat(pid, :RUN)
	      else
		p "ProcessMonitor: Unknown status %#x" % stat.to_i
	      end
	    end
	  rescue Errno::ECHILD
	    # ignore
	    puts "ProcessMonitor: #{$!}"
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

      @processes = []

      @thread = nil
      @stat = nil
      @mx = Mutex.new
      @cv = ConditionVariable.new

      @script = nil
    end
    attr_accessor :script

    def start(sync = true, &block)
      @stat = nil
      @thread = Thread.start {
#	Thread.abort_on_exception = true
	JobController::current_job = self
	v = block.call
	@mx.synchronize do
	  @stat = true
	  @cv.signal
	end
	v
      }

      if sync
	wait
      else
	# do nothing
      end 
    end

    def to_foreground
      @stat = nil
      wait
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
	  puts "enter background job and suspend system-command"
	else
	  p s
	end
      end
    end

    def throw_exception(*option)
      @thread.raise *option
    end

    def suspend
      @mx.synchronize do
	@stat = :TSTP
	@cv.signal
      end
    end


#    def start_backgorund_job(script)
#      
#    end

    def popen_process(com, *opts, &block)
      @processes.push com
      ProcessMonitor.Monitor.popen_process(com, *opts, &block)
    end

    def spawn_process(com, *opts)
      @processes.push com
      ProcessMonitor.Monitor.spawn_process(com, *opts)
    end
  end
end
