#
#   osspace.rb - 
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

module Reish
  module OSSpace

    def method_missing(name, *args)
      sh = Thread.current[:__REISH_CURRENT_SHELL__]
      return super unless sh
      back = Thread.current[:__REISH_CURRENT_SHELL__]
      Thread.current[:__REISH_CURRENT_SHELL__] = nil
      begin
	command = sh.search_command(self, name, *args)
      ensure
	Thread.current[:__REISH_CURRENT_SHELL__] = back
      end
      return super unless command
      command
    end
  end
end

class Object
  include Reish::OSSpace
end



