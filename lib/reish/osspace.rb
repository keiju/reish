#
#   osspace.rb - 
#   	Copyright (C) 2014-2017 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

module Reish
  module OSSpace

    def method_missing(name, *args, &block)

      return super unless Reish::active_thread?

      sh = Reish::current_shell
      command = sh.search_command(self, name, *args, &block)
      if command
	return command
      else
	return super
      end
    end

#     def method_missing(name, *args)
#       sh = Thread.current[:__REISH_CURRENT_SHELL__]
#       return super unless sh
#       back = Thread.current[:__REISH_CURRENT_SHELL__]
#       Thread.current[:__REISH_CURRENT_SHELL__] = nil
#       begin
# 	command = sh.search_command(self, name, *args)
#       ensure
# 	Thread.current[:__REISH_CURRENT_SHELL__] = back
#       end
#       return super unless command
#       command
#     end

  end
end




