#
#   reish/mainobj.rb - self in evaluate
#   	Copyright (C) 2014-2017 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#
require "forwardable"

require "reish/osspace"
require "reish/builtin-command"

module Reish
  class Main

    extend Forwardable

    include Enumerable
    include OSSpace
    include BuiltIn

    def initialize(exenv)
      @exenv = exenv
    end

    attr_reader :exenv

    def each &block
      STDIN.each &block
    end

    def_delegator :@exenv, :chdir
    def_delegator :@exenv, :chdir, :cd

    def_delegator :@exenv, :rehash

    def_delegator :@exenv, :display_mode
    def_delegator :@exenv, :display_mode=

    def_delegator :@exenv, :ignore_eof
    def_delegator :@exenv, :ignore_eof=


    def_delegator :@exenv, :verbose
    def_delegator :@exenv, :verbose=
    def_delegator :@exenv, :debug_input=
    def_delegator :@exenv, :display_comp
    def_delegator :@exenv, :display_comp=
    def_delegator :@exenv, :yydebug
    def_delegator :@exenv, :yydebug=

    def inspect
      if Reish::INSPECT_LEBEL < 3
	
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



