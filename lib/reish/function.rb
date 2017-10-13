#
#   function.rb - 
#   	Copyright (C) 2014-2017 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "stringio"

module Reish

#  module UserAliasSpace; end
  module UserFunctionSpace; end

  class ::Object
#    include UserAliasSpace, UserFunctionSpace
    include UserFunctionSpace
  end

  FunctionFactories = {}

  def self.define_function(klass, name, args, body, visitor)
    fact = FunctionFactory.new(klass, name, args, body, visitor)
    fact.function_class
  end

  class FunctionFactory

    F2mode = {
      reish_term: :TERM,
      reish_result: :RESULT,
      to_a: :TO_A ,
      reish_xnull: :XNULL,
      reish_resultl: :RESULTL,
      reish_none:  :NONE,
    }

    def initialize(klass, name, args, body, visitor)
      @klass = klass
      @name = name
      @args = args
      @body = body

      @visitor = visitor

      @function_class = make_function_class
    end

    attr_reader :function_class

    def make_function_class
      if Reish::UserFunctionSpace.const_defined?(class_name)
	cname = class_name
	Reish::UserFunctionSpace.module_eval{remove_const cname}
	F2mode.each_key do |prec|
	  fn = real_fn(prec)
	  @klass.module_eval{if method_defined?(prec); remove_method fn; end}
	end
      end

      code =<<-END_OF_CODE; line_no = __LINE__+1
      class Reish::UserFunctionSpace::#{class_name}<Function
	def method_missing(name, *args, &block)
	  if FunctionFactory::F2mode[name]
	    Factory.make_real_function(name)
	    @receiver.send(Factory.real_fn(name), *@args, &@block).send(name, *args, &block)
	  else
	    unless @receiver.respond_to?(Factory.real_fn(:reish_none))
	      Factory.make_real_function(:reish_none, name, noprec: true)
	    end
	    @receiver.send(Factory.real_fn(:reish_none), *@args, &@block).send(name, *args, &block)
	    end
	end
	self
      end
      END_OF_CODE

      if Reish::debug_function?
	puts "Function Class:"
	puts code
      end

      @function_class = eval code, binding, __FILE__, line_no
      me = self
      @function_class.module_eval{const_set :Factory, me}
      @function_class
    end
	  
    def make_real_function(name, prec=name, noprec: false)
      fn = real_fn(name)
      @body.pipeout = F2mode[name]
      body = @body.accept(@visitor)
      puts "def #{fn}#{arg_form}\n #{body}\nend" if Reish::debug_function?
      @klass.module_eval "def #{fn}#{arg_form}\n #{body} \nend"

      unless noprec
	puts fun_body(name, prec) if Reish::debug_function?
	@function_class.module_eval fun_body(name, prec)
      end
    end

    def class_name(klass = @klass, fn = @name)
      klass.name.sub("::", "_")+"_"+ escape(fn.split("_").collect{|e|e.capitalize}.join)
    end

    def arg_form(args = @args)
      args ||= []
      "(#{args.join(", ")})"
    end

    def fun_body(name, prec=name)
      %{def #{prec}(*args, &block)
          @receiver.#{real_fn(name)}(*@args, &@block).#{prec}(*args, &block)
       end}
    end

    def real_fn(name)
      "__reish_impl_#{escape(@name)}__#{name}"
    end

    ESC = {
      "-" => "_minus_",
      "+" => "_plus_",
    }

    def escape(str)
      str.gsub("_", "__").gsub(/(\-|\+)/){ESC[$1]}
    end
  end

  class Function
    include Enumerable

    undef reish_term, reish_result, reish_xnull, reish_stat

    def initialize(receiver, *args, &block)
      @receiver = receiver
      @args = args
      @block = block
    end

  end

end
