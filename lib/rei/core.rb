#
#   core.rb - 
#   	Copyright (C) 1996-2019 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

module REI
  class Core

    def initialize(ap_path)
      @conf = CoreConf.new(ap_path)
    end

    attr_reader :conf

    def active_thread?
      Thread.current[:__REI_CURRENT_SHELL__]
    end

    def current_shell(no_exception = nil)
      sh = Thread.current[:__REI_CURRENT_SHELL__]
      self.Fail NotExistCurrentShell unless no_exception || sh
      sh
    end

    def current_shell=(sh)
      Thread.current[:__REI_CURRENT_SHELL__] = sh
    end

    def current_job(no_exception = nil)
      job = Thread.current[:__REI_CURRENT_JOB__]
      self.Fail NotExistCurrentJob unless no_exception || job
      job
    end
    
    def current_job=(job)
      Thread.current[:__REI_CURRENT_JOB__] = job
    end
    
  end

end


