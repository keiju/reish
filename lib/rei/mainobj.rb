#
#   rei/mainobj.rb - self in evaluate
#   	Copyright (C) 2014-2017 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#
require "forwardable"

module REI
  class Main

    extend Forwardable
    include Enumerable
    
    def initialize(exenv)
      @exenv = exenv
    end

    attr_reader :exenv

    def each &block
      job = REI::current_job
      job.stdin_each &block
    end

    def_delegator :@exenv, :rehash

# add for reirb
    def_delegator :@exenv, :jobs
    def_delegator :@exenv, :fg
    def_delegator :@exenv, :bg

    def_delegator :@exenv, :display_mode
    def_delegator :@exenv, :display_mode=

    def_delegator :@exenv, :ignore_eof
    def_delegator :@exenv, :ignore_eof=


    def_delegator :@exenv, :verbose
    def_delegator :@exenv, :verbose=
    def_delegator :@exenv, :display_comp
    def_delegator :@exenv, :display_comp=

    def inspect
      if REI::INSPECT_LEBEL < 3
	
	ins = instance_variables.collect{|iv|
	  if iv == :@exenv
	    "@exenv=#{@exenv}"
	  else
	    v = instance_eval(iv.id2name).inspect
	    "#{iv}=#{v}"
	  end
	}.join(", ")
	"#<Reish::Main: #{ins}>"
      else
	super
      end
    end
  end
end



