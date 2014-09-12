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

    def_delegator :@__shell__, :rehash

  end
end



