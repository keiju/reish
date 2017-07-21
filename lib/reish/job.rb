#
#   job.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

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

  class Job
    def initialize(shell)
      @shell = shell

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
	Thread.abort_on_exception = true
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
  end
end
