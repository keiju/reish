#
#   process-monitor.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "ext/reish"

module Reish

  class ProcessMonitor

    def self.Monitor
      MAIN_SHELL.process_monitor
    end

    def initialize(term_ctl)
      @term_ctl = term_ctl

      @pid2exe = {}
      @pid2exe_mx = Mutex.new
      @pid2exe_cv = ConditionVariable.new

      @monitor = nil
      @monitor_queue = Queue.new
      @monitor_queue_rt = Queue.new
    end

    def entry_exe(pid, exe)
      @pid2exe_mx.synchronize do
	exe.pid = pid
	@pid2exe[pid] = exe
	exe.pstat = :RUN
	@pid2exe_cv.broadcast
      end
    end

    def del_exe(exe)
      @pid2exe_mx.synchronize do
	@pid2exe.delete(exe)
      end
    end

    def set_exe_stat(pid, stat)
      exe = @pid2exe[pid]
      unless exe
	puts "ProcessMonitor: process id[#{pid}] no exist(stat = #{stat})" if Reish::debug_jobctl?
	return
      end
      exe.pstat = stat
    end

    def set_exe_exit_stat(pid, stat, status)
      @pid2exe_mx.synchronize do
	until exe = @pid2exe[pid]
	  @pid2exe_cv.wait(@pid2exe_mx)
	end

	unless exe
	  puts "ProcessMonitor: process id[#{pid}] no exist(stat = #{stat})" if Reish::debug_jobctl?
	  return
	end
	exe.set_exit_stat(stat, status)
      end
    end

    def popen_exe(exe, *opts, &block)
      IO.popen(*opts) do |io|
	entry_exe(io.pid, exe)

	begin
	  block.call io
	ensure
	  exe.wait
	  del_exe(exe)
	end
      end
    end

    def spawn_exe(exe, *opts, &block)
      pid = Process.spawn(*opts)
      entry_exe(pid, exe)

      begin
	block.call
      ensure
	exe.wait
	del_exe(exe)
      end
    end

#     def start_monitor

# # ruby's Bug#13768
    Thread.start do
      loop do
	sleep 100
      end
    end

# #       Thread.start do
# # 	sleep 10
# #       end
#       @monitor = Thread.start{
# 	Thread.abort_on_exception = true
# 	loop do
# 	  puts "ProcessMonitor: event waiting" if Reish::debug_jobctl?
# 	  @monitor_queue.pop
# #	  Thread.stop
#	  child_handle
# 	end
#       }
#     end

    WAIT_FLAG = Process::WNOHANG|Process::WUNTRACED|Reish::WCONTINUED
    def child_handle
      puts "ProcessMonitor: event arrived" if Reish::debug_jobctl?
      
      begin
	loop do
	  pid, stat = Process.waitpid2(-1, WAIT_FLAG)
	  unless pid
	    puts "ProcessMonitor: waitpid2 can't get pid" if Reish::debug_jobctl?
	    #		sleep 1
	    #		pid, stat = Process.waitpid2(-1, wait_flag)
	    break unless pid
	  end
	  
	  case 
	  when stat.signaled?
	    puts "ProcessMonitor: child #{stat.pid} was killed by signal #{stat.termsig}" if Reish::debug_jobctl?
	    if stat.coredump?
	      puts "ProcessMonitor: child #{stat.pid} dumped core." if Reish::debug_jobctl?
	    end

	    set_exe_exit_stat(pid, :TERM, stat)
	    
	  when stat.stopped?
	    puts "ProcessMonitor: child #{stat.pid} was stopped by signal #{stat.stopsig}" if Reish::debug_jobctl?
	    case stat.stopsig
	    when 20
	      set_exe_stat(pid, :TSTP)
	      
	      MAIN_SHELL.reish_tstp(MAIN_SHELL) if @term_ctl
	      
	    when 21
	      set_exe_stat(pid, :TTIN)

	    when 22
	      set_exe_stat(pid, :TTOU)
	    else
	      
	    end

	  when stat.exited?
	    puts "ProcessMonitor: child #{stat.pid} exited normally. status=#{stat.exitstatus}" if Reish::debug_jobctl?

	    set_exe_exit_stat(pid, :EXIT, stat)

	  when Reish::wifscontinued?(stat)
	    puts "ProcessMonitor: child #{stat.pid} continued." if Reish::debug_jobctl?
	    set_exe_stat(pid, :RUN)
	  else
	    p "ProcessMonitor: Unknown status %#x" % stat.to_i if Reish::debug_jobctl?
	  end
	end
      rescue Errno::ECHILD
	# ignore
	puts "ProcessMonitor: #{$!}" if Reish::debug_jobctl?
      end
      #	  @monitor_queue_rt.push self
    end

    def accept_sigchild
puts "ACCEPT_SIGCHILD: IN" if Reish::debug_jobctl?
#      @monitor_queue.push self
      Thread.start do
	child_handle
      end
puts "ACCEPT_SIGCHILD: OUT" if Reish::debug_jobctl?
    end

  end

end
