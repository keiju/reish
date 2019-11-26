#
#   job.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

module Reish
  class Job
    def initialize(shell)
      @shell = shell
      @source = nil

      @current_exe = nil
      @thread = nil

      @foreground = nil
      @foreground_mx = Mutex.new
      @foreground_cv = ConditionVariable.new
      @enter_foreground_only = nil

      @suspend_wait_reason = nil
      @suspend_mx = Mutex.new
      @suspend_cv = ConditionVariable.new

      @wait_stat = nil
      @wait_mx = Mutex.new
      @wait_cv = ConditionVariable.new
    end

    attr_accessor :source
    attr_reader :foreground
    alias foreground? foreground

    attr_reader :wait_stat

    def wait_stat=(st)
      @wait_mx.synchronize do
	@wait_stat = st
	@wait_cv.broadcast
      end
    end

    def start(fg = true, &block)
      self.foreground = fg

      @wait_stat = nil
      @thread = Thread.start {
	Thread.abort_on_exception = true
	Reirb::current_job = self

	v = block.call

	@wait_mx.synchronize do
	  @wait_stat = true
	  @wait_cv.broadcast
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

    def to_fgbg(fg=true)
      self.foreground = fg
      job_cont
      if @current_exe
	set_ctlterm if @foreground
	Process.kill(:CONT, @current_exe.pid) if @current_exe.pstat_stop?
      end
#      if @foreground
#	wait
#      end
    end

    def foreground=(value)
      @foreground_mx.synchronize do
	@foreground=value
	@foreground_cv.broadcast
      end
    end


    def foreground_only(reason: "unknown", 
			pre_waiting_proc: nil, 
			post_waiting_proc: nil, 
			&block)
      @foregrond_mx.synchronize do
	until @foregrond && !@suspend_reserve
	  pre_waiting_proc.call(self) if pre_waiting_proc
	  @foreground_cv.wait(@foreground_mx)
	  post_waiting_proc.call(self) if post_waiting_proc
	end
			  
	begin
	  @suspend_wait_reason = reason
	  block.call
	ensure
	  @suspend_wait_reason = nil
	  @suspend_cv.broadcast
	end
      end
    end

    def loop_foreground_only(reason: "unknown", 
			     pre_waiting_proc: nil, 
			     post_waiting_proc: nil, 
			     &block)
      begin
	@enter_foreground_only = true
	@foreground_mx.synchronize do
	  loop do
	    until @foreground && !@suspend_reserve
	      pre_waiting_proc.call(self) if pre_waiting_proc
	      @foreground_cv.wait(@foreground_mx)
	      post_waiting_proc.call(self) if post_waiting_proc
	    end
	    begin
	      @suspend_wait_reason = reason
	      block.call
	    ensure
	      @suspend_wait_reason = nil
	      @suspend_cv.broadcast
	    end
	  end
	end
      ensure
	@enter_foreground_only = nil
      end
    end

    def suspend
      @suspend_mx.synchronize do
	while @suspend_wait_reason
	  puts "Wait suspending, because this job is executing critical section(#{@suspend_wait_reason})."
	  @suspend_reserve = true
	  @suspend_cv.wait(@suspend_mx)
	end
	begin
	  self.foreground = false
	  job_stop
	  @wait_mx.synchronize do
	    @wait_stat = :TSTP
	    @wait_cv.signal
	  end
	
	ensure
	  @suspend_reserve = false
	  @foreground_cv.broadcast
	end
      end
    end
	
    def job_stop
      @thread.set_trace_func proc{
	begin
	  if @enter_foreground_only && @foreground_mx.locked?
	    foreground_mx_unlock = true
	    @foreground_mx.unlock
	  end

	  Thread.stop

	ensure
	  if foreground_mx_unlock
	    @foreground_mx.lock
	  end
	end
      }
    end

    def job_cont
      @wait_stat = nil
      @thread.set_trace_func nil
      @thread.run
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


    def kill(signal=:SIGTERM)
      if @current_exe
	@current_exe.kill(signal)
      else
	unless [:SIGTERM, :TERM, "SIGTERM", "TERM", 15].include?(signal)
	  puts "ビルトインコマンドはSIGTERM以外ではkillできません."
	  raise ArgumentError, "Illegal signal specification"
	end
	@thread.raise Abort, "job abort signaled."
      end
    end

    def popen_exe(exe, *opts, &block)
      @current_exe = exe
      begin
	opts[-1][:pgroup] = true if term_ctl?
	ProcessMonitor.Monitor.popen_exe(exe, *opts) do |io|
	  #Reish.tcsetpgrp(STDOUT, io.pid) if @foreground
	  set_ctlterm if @foreground
	  block.call io
	end
      ensure
	#Reish.tcsetpgrp(STDOUT, Process.pid) if @foreground
	reset_ctlterm if @foreground
	exe = @current_exe
	@current_exe = nil
	if exe && exe.exit_status.signaled?
	  @thread.raise Abort, "job abort signaled."
	end
      end
    end

    def spawn_exe(exe, *opts, &block)
      @current_exe = exe
      begin
	opts[-1][:pgroup] = true if term_ctl?
	ProcessMonitor.Monitor.spawn_exe(exe, *opts) do
	  #Reish.tcsetpgrp(STDOUT, exe.pid) if @foreground
	  begin
	    set_ctlterm if @foreground
	  rescue Errno::ESRCH
	    # ignore
	  end
	end
      ensure
	# ここ(ctltermの再設定前)で, ^Cが発生すると無視される?
	reset_ctlterm if @foreground
	exe_b = @current_exe
	@current_exe = nil
	if exe_b.exit_status && exe_b.exit_status.signaled?
	  @thread.raise Abort, "job abort signaled."
	end
      end
    end

    def stdin_each(&block)
      back_st = nil
      pre_ttin_proc = proc{|job|
	unless job.foreground?
	  back_st = job.wait_stat
	  job.wait_stat = :TTIN
	  puts "suspend TTIN"
	end
      }
      post_ttin_proc = proc{|job|
	if back_st
	  job.wait_stat = back_st
	end
      }

      loop_foreground_only(reason: "STDIN",
			   pre_waiting_proc: pre_ttin_proc,
			   post_waiting_proc: post_ttin_proc) do
	break unless s = STDIN.gets
	block.call s
      end
    end

    def set_ctlterm
      begin
	MAIN_SHELL.set_ctlterm(@current_exe.pid)
      rescue Errno::ESRCH
      end
    end

    def reset_ctlterm
      begin
	MAIN_SHELL.set_ctlterm(nil)
      rescue Errno::ESRCH
      end
    end

    def term_ctl?
      MAIN_SHELL.term_ctl?
    end

    def info
      if @current_exe
	"<#{@source}(#{@wait_stat || :RUN}) exe=#{@current_exe.info}>"
      else
	"<#{@source}(#{@wait_stat || :RUN})>"
      end
    end

    def inspect
      return super if Reish::INSPECT_LEBEL >= 3
      
      "#<Job: @current_exe=#{@current_exe.inspect}>"
    end
  end

end
