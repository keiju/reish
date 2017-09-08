#
#   compspec.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)

require "reish/comp-module-spec"

module Reish

  class CompPipelineCall
    def initialize(receiver, pipeline, bind)
      @receiver = receiver
      @pipeline = pipeline
      @bind = bind
    end

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
	  when IDToken
	    name = com.name.value
	    var = eval("local_variables | self.class.constants(true) | Object.constants", @bind).find{|v| v.to_s == name}
	    if var
	      receiver = eval(var.to_s, @bind)
	    else
	      arg = CompCommandCall.new(receiver,
				       com.name,
				       com.args,
				       bind)
	      receiver = arg.return_value
	    end
	  when SpecialToken, ReservedWordToken, TestToken, PathToken
	    raise "not implemented for token: #{@name.inspect}"
	  else
	    raise "not implemented for token: #{@name.inspect}"
	  end
	  
	when last_comm
	  case receiver
	  when ModuleSpec, DescendantSpec, CompositeSpec
	    candidates = receiver.instance_methods
	  else
	    candidates = receiver.methods
	  end
	  case com.name
	  when IDToken
	    return candidates.grep(/^#{com.name.value}/)
	  when nil
	    return candidates
	  end
	else
	  arg = CompCommandCall.new(receiver,
				    com.name,
				    com.args,
				    bind)
	  receiver = arg.return_value
	end
      end
    end
  end

  class CompPipelineneArg
    def initialize(receiver, pipeline, last_arg, bind)
      @receiver = receiver
      @pipeline = pipeline
      @args = args
      @last_arg = last_arg
      @bind = bind
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
	  when IDToken
	    name = com.name.value
	    var = eval("local_variables | self.class.constants", @shell.exenv.binding).find{|v| v.to_s == name}
	    if var
	      receiver = eval(var, @shell.exenv.binding)
	    else
	      call = CompCommandCall.new(receiver,
				       com.name,
				       com.args,
				       last_arg,
				       bind)
	      receiver = call.return_value
	    end
	  when SpecialToken, ReservedWordToken, TestToken, PathToken
	    raise "not implemented for token: #{@name.inspect}"
	  else
	    raise "not implemented for token: #{@name.inspect}"
	  end
	  
	when last_comm
	  arg = CompCommandArg.new(receiver,
				   com.name,
				   com.args,
				   last_arg,
				   bind)
	  candidates = arg.candidates
	else
	  call = CompCommandCall.new(receiver,
				   com.name,
				   com.args,
				   nil,
				   bind)
	  receiver = call.return_value
	end
      end
      candidates
    end
  end

  class CompCommandBase
    def spec_name
      case @name
      when IDToken
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
    def initialize(receiver, name, args, bind)
      @receiver = receiver
      @name = name
      @args = args
      @bind = bind
    end

    attr_reader :bind
    attr_reader :receiver
    attr_reader :compspec
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
    def initialize(receiver, name, args, last_arg, bind)
      @receiver = receiver
      @name = name
      @args = args
      @last_arg = last_arg
      @bind = bind
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

