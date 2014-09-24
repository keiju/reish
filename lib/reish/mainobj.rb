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

  end
end



