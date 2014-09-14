#
#   reish/workspace.rb - shell's local variable space
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

require "reish/mainobj"

module Reish
  class WorkSpace

    # initialize()
    # initialize(bind)
    # initialize(main)
    # initialize(bind, main)
    def initialize(*main)
      if main[0].kind_of?(Binding)
	@binding = main.shift
      elsif Reish.conf[:SINGLE_REISH]
	@binding = TOPLEVEL_BINDING
      else
	case Reish.conf[:CONTEXT_MODE]
	when 0	# binding in proc on TOPLEVEL_BINDING
	  @binding = eval("proc{binding}.call",
		      TOPLEVEL_BINDING,
		      __FILE__,
		      __LINE__)

	when 1	# binding in loaded file

	  Reish.conf_tempkey("__TEMP_BINDING__") do |key|

	    require "tempfile"
	    f = Tempfile.open("reish-binding")
	    f.puts("Reish.conf[:#{key}]=binding)")
	    f.close
	    load f.path
	    @binding = Reish.conf[key]
	  end
	  
	when 2	# binding in loaded file(thread use)
	  unless defined? BINDING_QUEUE
	    require "tempfile"
	    require "thread"

	    IRB.const_set("BINDING_QUEUE", SizedQueue.new(1))
	    Thread.abort_on_exception = true
	    Thread.start do
	      f = Tempfile.open("reish-binding2")
	      f.puts("while true do Reish::BINDING_QUEUE.push binding; end")
	      f.close
	      load f.path

	      eval "load '#{f}'", TOPLEVEL_BINDING, __FILE__, __LINE__
	    end
	    Thread.pass
	  end
	  @binding = Reish::BINDING_QUEUE.pop

	when 3, nil # binging in function on TOPLEVEL_BINDING(default)
	  @binding = eval("def reish_binding; binding; end; reish_binding",
		      TOPLEVEL_BINDING,
		      __FILE__,
		      __LINE__ - 3)
	end
      end

      if main.empty?
	@main = Main.new(@shell)
      else
	@main = main[0]
      end
      
      Reish::conf_tempkey do |main_key|
	Reish.conf[main_key]=@main
	case @main
	when Module
	  @binding = eval("Resih.conf[:#{main_key}].module_eval('binding', __FILE__, __LINE__)", @binding, __FILE__, __LINE__)
	else
	  begin
	    @binding = eval("Reish.conf[:#{main_key}].instance_eval('binding', __FILE__, __LINE__)", @binding, __FILE__, __LINE__)
	  rescue TypeError
	    Reish.fail CantSetBinding, @main.inspect
	  end
	end
      end

      eval("_=nil", @binding)
    end

    attr_reader :binding
    attr_reader :main

    def evaluate(statements, file = __FILE__, line = __LINE__)
      Thread.current[:__REISH_CURRENT_SHELL__] = @main.__shell__
      begin
	eval(statements, @binding, file, line)
      ensure
	Thread.current[:__REISH_CURRENT_SHELL__] = nil
      end
    end

    # error message manipulator
    def filter_backtrace(bt)
      bt
#       case Reish.conf[:CONTEXT_MODE]
#       when 0
# 	return nil if bt =~ /\(irb_local_binding\)/
#       when 1
# 	if(bt =~ %r!/tmp/irb-binding! or
# 	   bt =~ %r!irb/.*\.rb! or
# 	   bt =~ /irb\.rb/)
# 	  return nil
# 	end
#       when 2
# 	return nil if bt =~ /irb\/.*\.rb/
# 	return nil if bt =~ /irb\.rb/
#       when 3
# 	return nil if bt =~ /irb\/.*\.rb/
# 	return nil if bt =~ /irb\.rb/
# 	bt.sub!(/:\s*in `irb_binding'/, '')
#       end
#       bt
    end

  end
end
