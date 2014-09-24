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

      return super unless Reish::active_thread?

      sh = Reish::current_shell
      command = sh.search_command(self, name, *args)
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

    def inspect
      if Reish::INSPECT_LEBEL < 3
	
	ins = instance_variables.collect{|iv|
	  if iv == :@__shell__
	    "@__shell__=#{@__shell__}>"
	  else
	    i = instance_eval{iv}.inspect
	    "#{iv}=#{i}"
	  end
	}.join(", ")
	"#<Reish::Main: #{ins}>"
      else
	super
      end
    end
  end
end




