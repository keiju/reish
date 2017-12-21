#
#   compspec.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)

require "reish/cmpl/comp-module-spec"

module Reish

  class CompPipelineCall
    def initialize(receiver, pipeline, shell)
      @receiver = receiver
      @pipeline = pipeline
      @shell = shell
      @bind = @shell.exenv.binding
    end

    attr_reader :shell
    attr_reader :bind
    attr_reader :receiver
    attr_reader :pipeline

    def candidates
      receiver = @receiver
      first_comm = @pipeline.commands.first
      last_comm = @pipeline.commands.last

      @pipeline.commands.each do |com|
	case com
	when first_comm
	  case com.name
	  when IDToken, ID2Token, TestToken
	    name = com.name.value
	    var = eval("local_variables | self.class.constants(true) | Object.constants", @bind).find{|v| v.to_s == name}
	    if var
	      receiver = eval(var.to_s, @bind)
	    else
	      call = CompCommandCall.new(receiver,
				       com.name,
				       com.args,
				       @shell)
	      receiver = call.return_value
	    end
	  when SpecialToken, ReservedWordToken, PathToken
	    raise "not implemented for token: #{@name.inspect}"
	  else
	    raise "not implemented for token: #{@name.inspect}"
	  end
	  
	when last_comm
	  if com&.name
	    call = CompCommandCall.new(@receiver, com.name, com.args, @shell)
	  else
	    call = nil
	  end
	  return Reish::CompCmdProc(call){|cpp|
	    case receiver
	    when ModuleSpec, DescendantSpec, CompositeSpec
	      cpp.add receiver.instance_methods.collect{|n| n.id2name}.sort, 
		tag: "Completing builtin methods:"
	    else
	      cpp.add receiver.methods.collect{|n| n.id2name}.sort, 
		tag: "Completing builtin methods:"
	    end
	    cpp.add @shell.all_commands, tag: "Completing external commands:"
	  }
	else
	  arg = CompCommandCall.new(receiver,
				    com.name,
				    com.args,
				    @shell)
	  receiver = arg.return_value
	end
      end
    end
  end

  class CompPipelineArg
    def initialize(receiver, pipeline, last_arg, shell)
      @receiver = receiver
      @pipeline = pipeline
      @args = args
      @last_arg = last_arg
      @shell = shell
      @bind = @shell.exenv.binding
    end

    attr_reader :bind
    attr_reader :receiver
    attr_reader :pipeline
    attr_reader :args
    attr_reader :last_arg

    def candidates
      receiver = @receiver
      first_comm = @pipeline.commands.first
      last_comm = @pipeline.commands.last
      
      @pipeline.commands.each do |com|
	case com
	when first_comm
	  case com.name
	  when IDToken, ID2Token, TestToken
	    name = com.name.value
	    var = eval("local_variables | self.class.constants(true) | Object.constants", @bind).find{|v| v.to_s == name}
	    if var
	      receiver = eval(var.to_s, @bind)
	    else
	      call = CompCommandCall.new(receiver,
					 com.name,
					 com.args,
					 @shell)
	      receiver = call.return_value
	    end
	  when SpecialToken, ReservedWordToken, PathToken
	    raise "not implemented for token: #{@name.inspect}"
	  else
	    raise "not implemented for token: #{@name.inspect}"
	  end
	  
	when last_comm
	  arg = CompCommandArg.new(receiver,
				   com.name,
				   com.args,
				   last_arg,
				   @shell)
	  return arg.candidates
	else
	  call = CompCommandCall.new(receiver,
				   com.name,
				   com.args,
				   @shell)
	  receiver = call.return_value
	end
      end
    end
  end

  class CompCommandBase
    def spec_name
      case @name
      when IDToken, ID2Token
	@name.value
      when SpecialToken
	"Special#"+@name.value
      when ReservedWordToken
	"RESERVED#"+@name.token_id.to_s
      when TestToken
	"TEST#"+@name.token_id.to_s
      when PathToken
	@name.value
      else
	raise "not implemented for token: #{@name.inspect}"
      end
    end
  end
    
  
  class CompCommandCall<CompCommandBase
    def initialize(receiver, name, args, shell)
      @receiver = receiver
      @name = name
      @args = args
      @shell = shell
      @bind = @shell.exenv.binding
    end

    attr_reader :bind
    attr_reader :receiver
    attr_reader :name
    attr_reader :args

    def return_value
      spec = Reish::CompSpec(@receiver, spec_name)
      spec.return_value(self)
    end

    def candidates
#      spec = Reish::CompSpec(@receiver, spec_name)
#      spec.ret_candidates(self)
    end

  end

  class CompCommandArg<CompCommandBase
    def initialize(receiver, name, args, last_arg, shell)
      @receiver = receiver
      @name = name
      @args = args
      @last_arg = last_arg
      @shell = shell
      @bind = @shell.exenv.binding
    end

    attr_reader :bind
    attr_reader :receiver
    attr_reader :compspec
    attr_reader :args
    attr_reader :last_arg

    def candidates
      spec = Reish::CompSpec(@receiver, spec_name)
      spec.arg_candidates(self)
    end
  end

end

