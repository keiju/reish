# coding: utf-8
#
#   rei/job.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

module REI
  class Job
    def initialize(shell)
      @shell = shell
      @source = nil

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
	REI::current_job = self

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
      unless [:SIGTERM, :TERM, "SIGTERM", "TERM", 15].include?(signal)
	puts "ビルトインコマンドはSIGTERM以外ではkillできません."
	raise ArgumentError, "Illegal signal specification"
      end
      @thread.raise Abort, "job abort signaled."
    end

    def info
      "<#{@source}(#{@wait_stat || :RUN})>"
    end

    def inspect
      return super if REI::INSPECT_LEBEL >= 3
      s = @source ? "@source=#{@source}, " : ""
      "#<Job: #{s}" >"
    end
  end

end
