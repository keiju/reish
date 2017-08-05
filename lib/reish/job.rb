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

    def start(fg = true, &block)
      self.foreground = fg

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


    def foreground_only(reason, &block)
      @foregrond_mx.synchronize do
	until @foregrond && !@suspend_reserve
	  @foreground_cv.wait(@foreground_mx)
	end
			  
	begin
	  @suspend_wait_reason = reason
	  block.call
	ensure
	  @suspend_wait_reason = nil
	end
      end
    end

    def loop_foreground_only_org(reason, &block)
      @foreground_mx.synchronize do
	loop do
	  until @foreground && !@suspend_reserve
	    @foreground_cv.wait(@foreground_mx)
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
    end

    def loop_foreground_only(reason, &block)
      begin
	@enter_foreground_only = true
	@foreground_mx.synchronize do
	  loop do
	    until @foreground && !@suspend_reserve
	      @foreground_cv.wait(@foreground_mx)
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
