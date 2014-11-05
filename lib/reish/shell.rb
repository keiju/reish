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

require "reish/builtin-command"

module Reish 
  class Shell
    def initialize(input_method = nil)

      @thread = Thread.current if defined? Thread
      
      @ap_name = Reish.conf[:AP_NAME]

      self.display_mode = Reish.conf[:DISPLY_MODE]

      @ignore_sigint = Reish.conf[:IGNORE_SIGINT]
      @ignore_eof = Reish.conf[:IGNORE_EOF]

      @back_trace_limit = Reish.conf[:BACK_TRACE_LIMIT]

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
      @command_cache = COMMAND_CACHE_BASE.dup

      @verbose = Reish.conf[:VERBOSE]
      @display_comp = Reish.conf[:DISPLAY_COMP]
      @debug_input = Reish.conf[:DEBUG_INPUT]
      self.yydebug = Reish::conf[:YYDEBUG]

      @signal_status = :IN_IRB
      Reish.conf[:REISH_RC].call(self) if Reish.conf[:REISH_RC]
    end

    attr_reader :thread

    attr_reader :display_mode

    attr_reader :use_readline
    alias use_readline? use_readline

    attr_reader :pwd

    attr_accessor :ignore_eof
    alias ignore_eof? ignore_eof

    attr_accessor :ignore_sigint
    alias ignore_sigint? ignore_sigint

    attr_accessor :verbose
    alias verbose? verbose

    attr_accessor :display_comp
    attr_accessor :debug_input

    def initialize_as_main_shell
      trap("SIGINT") do
	signal_handle
      end
    end

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
	if ltype
	  @io.prompt = "reish:#{indent.inspect}:#{line_no}#{ltype} "
	elsif continue
	  @io.prompt = "reish:#{indent.inspect}:#{line_no}? "
	else
	  @io.prompt = "reish:#{indent.inspect}:#{line_no}> "
	end
      end

      @lex.set_input(@io) do
	signal_status(:IN_INPUT) do
	  if l = @io.gets
	    print l if verbose?
	  else
	    if ignore_eof? and @io.readable_after_eof?
	      l = "\n"
	      if verbose?
		printf "Use \"exit\" to leave %s\n", @ap_name
	      end
	    else
	      print "\n"
	    end
	  end
	  l
	end
      end

      begin
	catch(:REISH_EXIT) do
	  eval_input
	end
      ensure
      end
    end

    def eval_input
      @lex.initialize_input

      loop do
	@lex.lex_state = Lex::EXPR_BEG
	@current_input_unit = nil
	begin
	  @current_input_unit = @parser.do_parse
	  p @current_input_unit if @debug_input
	rescue ParseError => exc
	  puts exc.message
	  @lex.reset_input
	rescue Interrupt => exc
	  
	rescue => exc
	  handle_exception(exc)
	end

	next unless @current_input_unit
	break if Node::EOF == @current_input_unit 
	if Node::NOP == @current_input_unit 
	  puts "<= (NL)" if @display_comp
	  next
	end
	exp = @current_input_unit.accept(@codegen)
	puts "<= #{exp}" if @display_comp
	exc = nil
	begin
	  val = nil
	  signal_status(:IN_EVAL) do
	    activate_command_search do 
	      val = @workspace.evaluate(exp)
	    end
	  end
	  display val
	rescue Interrupt => exc
	rescue SystemExit, SignalException
	  raise
	rescue Exception => exc
	end
	handle_exception(exc, exp) if exc
      end
    end

    def display(val)
      puts "=> #{@display_method.inspect_value(val)}"
    end

    def handle_exception(exc, exp = nil)
      messages = ["#{exc.class}: #{exc}"]
      lasts = []
      levels = 0

      for m in exc.backtrace
	if messages.size < @back_trace_limit
	  messages.push "\tfrom "+m
	else
	  lasts.push "\tfrom "+m
	  if lasts.size > @back_trace_limit
	    lasts.shift
	    levels += 1
	  end
	end
      end
      print messages.join("\n"), "\n"
      unless lasts.empty?
	printf "... %d levels...\n", levels if levels > 0
	print lasts.join("\n")
      end

      puts "generated code: #{exp}" if exp
    end

    def signal_handle
      unless ignore_sigint?
	print "\nabort!!\n" if verbose?
	exit
      end

      case @signal_status
      when :IN_INPUT
	print "^C\n"
	raise Interrupt
      when :IN_EVAL
	reish_abort(self)
      when :IN_LOAD
	reish_abort(self, LoadAbort)
      when :IN_IRB
	# ignore
      else
	# ignore other cases as well
      end
    end

    def signal_status(status)
      return yield if @signal_status == :IN_LOAD

      signal_status_back = @signal_status
      @signal_status = status
      begin
	yield
      ensure
	@signal_status = signal_status_back
      end
    end

    def reish_exit(irb, ret)
      throw :REISH_EXIT, ret
    end

    def reish_abort(irb, exception = Abort)
      if defined? Thread
	thread.raise exception, "abort then interrupt!!"
      else
	raise exception, "abort then interrupt!!"
      end
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
    NO_SEARCH_METHODS = [:to_s, :to_a, :to_ary, :to_enum, :to_hash, :to_int, :to_io, :to_proc, :to_regexp, :to_str]
    COMMAND_CACHE_BASE = {}
    NO_SEARCH_METHODS.each do |m|
      COMMAND_CACHE_BASE[m] = :COMMAND_NOTHING
    end

    def search_command(receiver, name, *args)

      inactivate_command_search do
	path = @command_cache[name]
	case path
	when nil
	when :COMMAND_NOTHING
	  return nil
	else
	  return Reish::SystemCommand(self, receiver, path, *args)
	end

	n = name.to_s
	c = n.count("/")
	if c > 0
	  if n[0] == "/" && c == 1
	    n[0] = ""
	  else
	    path = File.absolute_path(n, @pwd)
	    if File.executable?(path)
	      @command_cache[name] = path
	      return Reish::SystemCommand(self, receiver, path, *args)
	    else
	      @command_cache[name] = :COMMAND_NOTHING
	      return nil
	    end
	  end
	end

	for dir_name in @system_path
	  p = File.expand_path(dir_name+"/"+n, @pwd)
	  if File.exist?(p)
	    path = p
	    break 
	  end
	end
	if path
	  @command_cache[name] = p
	  Reish::SystemCommand(self, receiver, path, *args)
	else
	  @command_cache[name] = :COMMAND_NOTHING
	  nil
	end
      end
    end

    def activate_command_search(&block)
      sh = Thread.current[:__REISH_CURRENT_SHELL__]
      Thread.current[:__REISH_CURRENT_SHELL__] = self
      begin
	block.call self
      ensure
	Thread.current[:__REISH_CURRENT_SHELL__] = sh
      end
    end

    def inactivate_command_search(&block)
      sh = Thread.current[:__REISH_CURRENT_SHELL__]
      return ifnoactive.call if !sh && ifnoactive

      back = sh
      Thread.current[:__REISH_CURRENT_SHELL__] = nil
      begin
	block.call sh
      ensure
	Thread.current[:__REISH_CURRENT_SHELL__] = back
      end
    end

    def rehash
      @command_cache = COMMAND_CACHE_BASE.dup
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

    def send_with_redirection(receiver, method, args, reds, &block)

      if inactivate_command_search{receiver.respond_to?(method, true)}
	input = nil
	output = nil
	reds.each do |r|
	  case r.id
	  when "<"
	    input = r
	  when ">", ">>"
	    output = r
	  when "&>", "&>>"
	    output = r
	  else
	    raise ArgumentError, "can't use redirection which specify source"
	  end
	end

	if input
	  case input.red
	  when String
	    receiver = open_file(input.red)
	  else
	    raise ArgumentError, "redirect target must be String"
	  end
	end
	if output
	  ret = nil
	  open_file(output.red, output.open_mode) do |io|
	    ret = receiver.send(method, *args, &block).each{|e|
	      io.print e
	    }
	  end
	  ret
	else
	  receiver.send(method, *args, &block)
	end
      else
	com = search_command(receiver, method, *args)
	com.reds = reds
	com
      end
    end

    def expand_path(name, base = @pwd)
      File.expand_path(name, base)
    end

    def open_file(name, mode = "r", perm = 0666, &block)
      path = expand_path(name)
      File.open(path, mode, perm, &block)
    end

    def yydebug=(val)
      @parser.yydebug = val
      @lex.debug_lex_state=val
    end

  end
end
