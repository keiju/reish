#
#   reish/mainobj.rb - self in evaluate
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#
require "forwardable"

require "reish/osspace"

module Reish
  class Main
    extend Forwardable

    include OSSpace

    def initialize(shell)
      @__shell__ = shell
    end

    attr_reader :__shell__

    def_delegator :@__shell__, :rehash
    def_delegator :@__shell__, :display_mode
    def_delegator :@__shell__, :display_mode=

    def_delegator :@__shell__, :ignore_eof
    def_delegator :@__shell__, :ignore_eof=


    def_delegator :@__shell__, :verbose
    def_delegator :@__shell__, :verbose=
    def_delegator :@__shell__, :debug_input=
    def_delegator :@__shell__, :display_comp
    def_delegator :@__shell__, :display_comp=
    def_delegator :@__shell__, :yydebug
    def_delegator :@__shell__, :yydebug=

    def inspect
      if Reish::INSPECT_LEBEL < 3
	
	ins = instance_variables.collect{|iv|
	  if iv == :@__shell__
	    "@__shell__=#{@__shell__}"
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



