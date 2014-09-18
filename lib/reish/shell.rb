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

require "reish/workspace"
require "reish/system-command"

require "reish/lex"
require "reish/parser"
require "reish/codegen"


module Reish 
  class Shell
    def initialize(pwd = Dir.pwd)
      self.output_mode = Reish.conf[:OUTPUT_MODE]

      @ignore_sigint = IRB.conf[:IGNORE_SIGINT]
      @ignore_eof = IRB.conf[:IGNORE_EOF]

      @lex = Lex.new
      @parser = Parser.new(@lex)
      @codegen = CodeGenerator.new
      @workspace = WorkSpace.new(Main.new(self))

      @pwd = pwd
      @system_path = ENV["PATH"].split(":")
      @system_env = ENV

      # name => path
      @command_cache = {}
    end

    attr_accesor :output_mode

    attr_reader :pwd

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
	@lex.lex_state = :EXPR_BEG
	@current_input_unit = @parser.do_parse
#	p @current_input_unit
	break if Node::EOF == @current_input_unit 
	if Node::NOP == @current_input_unit 
	  puts "<= (NL)"
	  next
	end
	exp = @current_input_unit.accept(@codegen)
	puts "<= #{exp}"
	val = @workspace.evaluate(exp)
	puts "=> #{val.inspect}"
      end
    end

    #
    # command methods
    def search_command(receiver, name, *args)

      path = @command_cache[name]
      if path
	return Reish::SystemCommand(self, receiver, path, *args)
      end

      n = name.to_s

      if n.include?("/")
	path = File.absolute_path(n, @pwd)
	return nil unless File.executable?(path)

	@command_cache[name] = path
	return Reish::SystemCommand(self, receiver, path, *args)
      end

      for dir_name in @system_path
	p = File.expand_path(dir_name+"/"+n, @pwd)
	if File.exist?(p)
	  @command_cache[name] = p
	  path = p
	  break 
	end
      end
      return nil unless path
      Reish::SystemCommand(self, receiver, path, *args)
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
