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
      command = @__shell__.search_command(self, name, *args)
      super unless command
      command
    end
  end
end

