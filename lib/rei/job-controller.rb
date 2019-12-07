# coding: utf-8
#
#   rei/job-controller.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "rei/job"

module REI

  class JobController
    def initialize(shell)
      @shell = shell

      @foreground_job = nil
      @jobs = []
    end

    attr_reader :jobs

    
    def kill_jobs(signal=:SIGTERM, *jobs)
      jobs.each do |jid|
	job = @jobs[jid]
	REI::Fail NoSuchJob, "%"+jid unless job
	job.kill(signal)
      end
    end

    def shrink_jobs
      until @jobs.empty? || @jobs.last; @jobs.pop; end
    end

    def fgbg(fg = true, id=nil)
      id = @jobs.size-1 unless id
      job = @jobs[id]
      REI::fail NoTargetJob unless job
      if fg
	@foreground_job.instance_eval{@foreground=false} if @foreground_job
	@foreground_job = job
	@jobs[id] = nil
	shrink_jobs
      end
      job.to_fgbg(fg)
    end

    def entry_job(job, fg = true, script=nil, &block)
#      job = Job.new(@shell)
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

end
