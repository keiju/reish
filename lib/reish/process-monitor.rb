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
    end

    def entry_exe(pid, exe)
      @pid2exe_mx.synchronize do
	exe.pid = pid
	@pid2exe[pid] = exe
	exe.pstat = :RUN
	@pid2exe_cv.broadcast
      end
      begin
	pid, stat = Process.waitpid2(pid, WAIT_FLAG)
	if pid
	  postproc_pid(pid, stat)
	end
      rescue Errno::ECHILD
      end
    end

    def del_exe(exe)
      @pid2exe_mx.synchronize do
	pid = exe.pid
	if pid
	  @pid2exe.delete(exe.pid)
	else
	  puts "ProcessMonitor: process(#{exe.info}) no entried" if Reish::debug_jobctl?
	end
      end
    end

    def wait_pids
      @pid2exe_mx.synchronize do
	@pid2exe.keys
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
	begin
	  entry_exe(io.pid, exe)
	  block.call io
	ensure
	  exe.wait
	  del_exe(exe)
	end
      end
    end

    def spawn_exe(exe, *opts, &block)
      pid = Process.spawn(*opts)
      begin
	entry_exe(pid, exe)
	block.call
      ensure
	exe.wait
	del_exe(exe)
      end
    end

    def start_monitor

      # ruby's Bug#13768
      Thread.start do
	loop do
	  sleep 100
	end
      end
      
#       Thread.start do
# 	sleep 10
#       end

      @monitor = Thread.start{
 	Thread.abort_on_exception = true
 	loop do
 	  puts "ProcessMonitor: event waiting" if Reish::debug_jobctl?
 	  @monitor_queue.pop
	  #	  Thread.stop
	  child_handle
 	end
      }
    end

    WAIT_FLAG = Process::WNOHANG|Process::WUNTRACED|Reish::WCONTINUED
    def child_handle
      puts "ProcessMonitor: event arrived" if Reish::debug_jobctl?

      wait_pids.each do |pid|
	begin
	  pid, stat = Process.waitpid2(pid, WAIT_FLAG)
	  if pid
	    postproc_pid(pid, stat)
	  else
	    puts "ProcessMonitor: waitpid2: process status not changed(pid=#{pid})" if Reish::debug_jobctl?
	  end
	rescue Errno::ECHILD
	  # ignore
#	  puts "ProcessMonitor: #{$!}" if Reish::debug_jobctl?
	end
      end
    end

    def postproc_pid(pid, stat)
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

    def accept_sigchild
STDOUT.syswrite "ACCEPT_SIGCHILD: IN\n" if Reish::debug_jobctl?
      @monitor_queue.push self
#      Thread.start do
#	child_handle
#      end
STDOUT.syswrite "ACCEPT_SIGCHILD: OUT\n" if Reish::debug_jobctl?
    end

  end

end
