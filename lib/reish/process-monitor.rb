#
#   process-monitor.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

module Reish

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

end
