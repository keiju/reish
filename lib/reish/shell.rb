#
#   reish/shell.rb - 
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

require "reish/workspace.rb"

require "reish/lex.rb"
require "reish/parser.rb"
require "reish/codegen.rb"

module Reish 
  class Shell
    def initialize(pwd = Dir.pwd)
      @lex = Lex.new
      @parser = Parser.new(@lex)
      @codegen = CodeGenerator.new
      @workspace = WorkSpace.new

      @pwd = pwd
      @system_path = ENV["PATH"].split(":")
      @system_env = ENV

      # name => path
      @command_cache = {}
    end

    def start
      @lex.set_prompt do |ltype, indent, continue, line_no|
	"reish>"
      end

      @lex.set_input(STDIN)
      eval_input
    end

    def eval_input
      @lex.initialize_input

      loop do
	@current_input_unit = @parser.do_parse
	p @current_input_unit
	break if Node::EOF == @current_input_unit 
	if Node::NOP == @current_input_unit 
	  puts "OUTPUT: (NL)"
	  next
	end
	exp = @current_input_unit.accept(@codegen)
	puts "OUTPUT: #{exp}"
      end
    end

    #
    # command methods
    def search_command(receiver, name, *args)
      path = @command_cache[name]
      unless path
	for dir_name in @system_path
	  p = File.expand_path(dir_name+"/"+name, @pwd)
	  if File.exist?(p)
	    @command_cache[name] = p
	  end
	end
	return nil
      end

      SystemCommand(self, receiver, name, *args)
    end

    def rehash
      @command_cache.clear
    end

    def system_path=(path)
      case path
      when String
	@system_path = path.split(":")
      when Array
	@system_path = path
      else
	raise TypeError
      end

      @comand_cache.clear

      if @sytem_env.equal?(ENV)
	@system_env = @system_env.to_hash
      end

      @system_env["PATH"] = @system_path.join(":")

    end

    attr_reader :system_env

  end
end
