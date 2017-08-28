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
#      "none" => :NONE,
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
      code = StringIO.new
      code.puts "class #{class_name}<Function"; line_no = __LINE__+1

      code.puts "def method_missing(name, *args, &block)"
      code.puts "  if FunctionFactory::F2mode[name]"
      code.puts "    Factory.make_real_function(name)"
      code.puts "    @receiver.send(Factory.real_fn(name), *@args, &@block).send(name, *args, &block)"
      code.puts "  else"
      code.puts "    unless @receiver.respond_to?(Factory.real_fn('none'))"
      code.puts "      Factory.make_real_function('none', name)"
      code.puts "    end"
      code.puts "    @receiver.send(Factory.real_fn('none'), *@args, &@block).send(name, *args, &block)"
      code.puts "  end"
      code.puts "end"
      
      code.puts "self"
      code.puts "end"

      if Reish::debug_function?
	puts "Function Class:"
	puts code.string
      end

      @function_class = eval code.string, binding, __FILE__, line_no
      me = self
      @function_class.module_eval{const_set :Factory, me}
      @function_class
    end
	  
    def make_real_function(name, pre=name)
      fn = real_fn(name)
      @body.pipeout = F2mode[name]
      body = @body.accept(@visitor)
p arg_form, @args
      puts "def #{fn}#{arg_form}\n #{body}\nend" if Reish::debug_function?

      @klass.module_eval "def #{fn}#{arg_form}\n #{body} \nend"
      @function_class.module_eval fun_body(name, pre)
    end

    def class_name(klass = @klass, fn = @name)
      klass.name+"_"+ fn.split("_").collect{|e|e.capitalize}.join
    end

    def arg_form(args = @args)
      args ||= []
      "(#{args.join(", ")})"
    end

    def fun_body(name, pre=name)
      %{def #{pre}#{arg_form}
          @receiver.#{real_fn(name)}(*@args, &@block).#{pre}
	end}
    end

    def real_fn(name)
      "#{@name}__#{name}"
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
