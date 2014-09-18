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

require "reish/input-method"
require "irb/inspector"

module Reish 
  class Shell
    def initialize(input_method = nil)
      
      @verbose = Reish.conf[:VERBOSE]

      self.display_mode = Reish.conf[:DISPLY_MODE]
      @display_comp = Reish.conf[:DISPLY_COMP]

      @ignore_sigint = Reish.conf[:IGNORE_SIGINT]
      @ignore_eof = Reish.conf[:IGNORE_EOF]

      @use_readline = Reish.conf[:USE_READLINE]
      initialize_input_method(input_method)

      @lex = Lex.new
      @parser = Parser.new(@lex)
      @codegen = CodeGenerator.new
      @workspace = WorkSpace.new(Main.new(self))

      @pwd = Dir.pwd
      @system_path = ENV["PATH"].split(":")
      @system_env = ENV

      # name => path
      @command_cache = {}
    end

    attr_accessor :verbose
    attr_reader :display_mode
    attr_accessor :display_comp

    attr_reader :use_readline
    alias use_readline? use_readline

    attr_reader :pwd

    def initialize_input_method(input_method)
      case input_method
      when nil
	case use_readline?
	when nil
	  if defined?(ReadlineInputMethod) && STDIN.tty?
	    @io = ReadlineInputMethod.new
	  else
	    @io = StdioInputMethod.new
	  end
	when false
	  @io = StdioInputMethod.new
	when true
	  if defined?(ReadlineInputMethod)
	    @io = ReadlineInputMethod.new
	  else
	    @io = StdioInputMethod.new
	  end
	end
      when String
	@io = FileInputMethod.new(input_method)
	@irb_name = File.basename(input_method)
	@irb_path = input_method
      else
	@io = input_method
      end
    end

    def start
      @lex.set_prompt do |ltype, indent, continue, line_no|
	@io.prompt = "reish> "
      end

      @lex.set_input(@io) do
#	signal_status(:IN_INPUT) do
	  if l = @io.gets
	    print l if verbose?
	  else
	    if ignore_eof? and @io.readable_atfer_eof?
	      l = "\n"
	      if verbose?
		printf "Use \"exit\" to leave %s\n", @context.ap_name
	      end
	    else
	      print "\n"
	    end
	  end
	  l
#	end
      end

      eval_input
    end

    def eval_input
      @lex.initialize_input

      loop do
	@lex.lex_state = :EXPR_BEG
	@current_input_unit = @parser.do_parse
	p @current_input_unit
	break if Node::EOF == @current_input_unit 
	if Node::NOP == @current_input_unit 
	  puts "<= (NL)"
	  next
	end
	exp = @current_input_unit.accept(@codegen)
	puts "<= #{exp}" if @display_comp
	val = @workspace.evaluate(exp)
	display val
      end
    end

    def display(val)
      puts "=> #{@display_method.inspect_value(val)}"
    end

    #
    def verbose?
      if @verbose.nil?
	if defined?(ReadlineInputMethod) && @io.kind_of?(ReadlineInputMethod)
	  false
	elsif !STDIN.tty? or @io.kind_of?(FileInputMethod)
	  true
	else
	  false
	end
      else
	@verbose
      end
    end


    #
    #
    def display_mode=(opt)
      if i = IRB::INSPECTORS[opt]
	@display_mode = opt
	@display_method = i
	i.init
      else
	case opt
	when nil
	  self.display_mode = true
	when /^\s*\{.*\}\s*$/
	  begin
	    inspector = eval "proc#{opt}"
	  rescue Exception
	    puts "Can't switch inspect mode(#{opt})."
	    return
	  end
	  self.display_mode = inspector
	when Proc
	  self.display_mode = IRB::Inspector(opt)
	when Inspector
	  prefix = "usr%d"
	  i = 1
	  while INSPECTORS[format(prefix, i)]; i += 1; end
	  @display_mode = format(prefix, i)
	  @display_method = opt
	  INSPECTORS.def_inspector(format(prefix, i), @display_method)
	else
	  puts "Can't switch inspect mode(#{opt})."
	  return
	end
      end
#      print "Switch to#{unless @inspect_mode; ' non';end} inspect mode.\n" if verbose?
      @display_mode
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
