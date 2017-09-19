#
#   reish/shell.rb - 
#   	Copyright (C) 2014-2017 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

require "reish/exenv"
require "reish/system-command"

require "reish/lex"
require "reish/parser"
require "reish/code-generator"
require "reish/job-controller"
require "reish/process-monitor"

require "reish/input-method"
require "irb/inspector"

require "reish/builtin-command"

module Reish 
  class Shell
    def initialize(input_method = nil)

#      @thread = Thread.current

      @io = nil

      @lex = Lex.new
      @parser = Parser.new(@lex)
      @codegen = CodeGenerator.new

      @job_controller = JobController.new(self)

      @exenv = Exenv.new(self, Reish.conf)
      initialize_input_method(input_method)

      # name => path
      @command_cache = COMMAND_CACHE_BASE.dup

      @signal_status_mx = Mutex.new
      @signal_status = :IN_IRB

      @current_input_unit = nil

      @parser.yydebug = Reish::debug_yy?
    end

#    attr_reader :thread
    attr_reader :exenv

    attr_reader :io
    attr_reader :lex
    attr_reader :job_controller
    attr_reader :codegen

    attr_reader :completor

    def initialize_input_method(input_method)
      case input_method
      when nil
	case @exenv.use_readline?
	when nil
	  if STDIN.tty?
	    @io = Reish::comp[:INPUT_METHOD][:TTY].new
	  else
	    @io = StdioInputMethod.new
	  end
	when false
	  @io = StdioInputMethod.new
	when true
	  @io = @exenv.tty_input_method.new
	end
      when String
	@io = FileInputMethod.new(input_method)
	@exenv.ap_name = File.basename(input_method)
	@exenv.src_path = input_method
      else
	@io = input_method
      end
      if @io.completable? && @exenv.completion? 
	@completor = Reish::comp[:COMPLETOR].new(self) 
	@io.completor = @completor
      end

    end

    def start
      @lex.set_prompt do |ltype, indent, continue, line_no|
	
	@io.prompt = @exenv.prompt.call(@exenv, line_no, indent, ltype, continue)
      end

      @lex.set_input(@io) do
	signal_status(:IN_INPUT) do
	  if l = @io.gets
	    print l if @exenv.verbose?
	  else
	    if @exenv.ignore_eof? and @io.readable_after_eof?
	      l = "\n"
	      if @exenv.verbose?
		printf "Use \"exit\" to leave %s\n", @exenv.ap_name
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
	  @current_input_unit = input_unit
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
	  puts "<= (NL)" if @exenv.display_comp
	  next
	end
	exp = @current_input_unit.accept(@codegen)
	puts "<= #{exp}" if @exenv.display_comp

	start_job(true, exp) do
	  eval(exp, @exenv.binding, @exenv.src_path, @lex.prev_line_no)
	end

      end
    end

    def input_unit
#      loop do
#	catch(:REIDLINE_TAG) do 

	  @current_input_unit = @parser.do_parse
#	  if @io.kind_of?(ReidlineInputMethod)
#	    @io.input_complete
#	  end
	  input = @lex.reset_readed
	  if Reish::debug_input?
	    puts "input: #{input}"
	    puts "input_unit: #{@current_input_unit.pretty_inspect}"
	  end
          @current_input_unit
#	end

#	if ret
#	  return @current_input_unit
#	else
#	  @lex.reset_input
#	end
#      end
    end

    def start_job(fg, exp, &block)
      @job_controller.start_job(fg, exp) do
	exc = nil
	val = nil
	begin
	  signal_status(:IN_EVAL) do
	    activate_command_search do 
	      val = block.call
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
      puts "=> #{@exenv.display_method.inspect_value(val)}"
    end

    def handle_exception(exc, exp = nil)
      messages = ["#{exc.class}: #{exc}"]
      lasts = []
      levels = 0

      for m in exc.backtrace
	if messages.size < @exenv.back_trace_limit
	  messages.push "\tfrom "+m
	else
	  lasts.push "\tfrom "+m
	  if lasts.size > @exenv.back_trace_limit
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

    def signal_handle(signal = :INT)
      case signal
      when :INT
	unless @exenv.ignore_sigint?
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
      when :TSTP
	case @signal_status
	when :IN_EVAL
	  print "^Z"
	  reish_tstp(self)
	when :IN_INPUT, :IN_EVAL, :IN_LOAD, :IN_IRB
	  # ignore
	else
	  # ignore other cases as well
	end

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
      @job_controller.raise_foreground_job  exception, "abort then interrupt!!"
    end

    def reish_tstp(shell)
      th = Thread.start do
	th.abort_on_exception = true
	puts "catch TSTP"
	@job_controller.suspend_foreground_job
      end
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
	  return Reish::SystemCommand(@exenv, receiver, path, *args)
	end

	n = name.to_s
	c = n.count("/")
	if c > 0
	  if n[0] == "/" && c == 1
	    n[0] = ""
	  else
	    path = File.absolute_path(n, @exenv.pwd)
	    if File.executable?(path)
	      @command_cache[name] = path
	      return Reish::SystemCommand(@exenv, receiver, path, *args)
	    else
	      @command_cache[name] = :COMMAND_NOTHING
	      return nil
	    end
	  end
	end

	for dir_name in @exenv.path
	  p = File.expand_path(dir_name+"/"+n, @exenv.pwd)
	  if File.exist?(p)
	    path = p
	    break 
	  end
	end
	if path
	  @command_cache[name] = p
	  Reish::SystemCommand(@exenv, receiver, path, *args)
	else
	  @command_cache[name] = :COMMAND_NOTHING
	  nil
	end
      end
    end

    def activate_command_search(&block)
      sh = Reish::current_shell(true)
      Reish::current_shell = self
      begin
	block.call self
      ensure
	Reish::current_shell = sh
      end
    end

    def inactivate_command_search(&block)
      sh = Reish::current_shell(true)
      return ifnoactive.call if !sh && ifnoactive

      back = sh
      Reish::current_shell = nil
      begin
	block.call sh
      ensure
	Reish::current_shell = back
      end
    end

    def rehash
      @command_cache = COMMAND_CACHE_BASE.dup
    end

    def all_commands(prefix = "")
      commands = []
      for dir_name in @exenv.path
	d = File.expand_path(dir_name, @exenv.pwd)
	begin
	  Dir::foreach(d) do |p|
	    a = d+"/"+p
	    st = File.stat(a)
	    next unless st.file? && st.executable?
	    commands.push p 
	  end
	rescue Errno::ENOENT
	end
      end

      commands.sort!.uniq!
      commands
      []
    end

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
	unless com = search_command(receiver, method, *args)
	  raise NoMethodError, "undefined medhod `#{method}'"
	end
	com.reds = reds
	com
      end
    end

    def shell_command_with_redirection(receiver, code, reds, bind)

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
	  p input
	  receiver = open_file(input.red)
	else
	  raise ArgumentError, "redirect target must be String"
	end
      end
      if output
	ret = nil
	open_file(output.red, output.open_mode) do |io|
	  ret = receiver.reish_eval(code, bind).each{|e|
	    io.print e
	  }
	end
	ret
      else
	receiver.reish_eval(code, bind)
      end
    end

    def expand_path(name, base = @exenv.pwd)
      File.expand_path(name, base)
    end

    def open_file(name, mode = "r", perm = 0666, &block)
      path = expand_path(name)
      File.open(path, mode, perm, &block)
    end

    def yydebug=(val)
      @parser.yydebug = val
    end
  end

  class MainShell < Shell

    def initialize(input_method = nil)
      super

      begin
	require "ext/reish"
	Reish::conf[:LIB_TERMCTL] = true
      rescue LoadError
	Reish::conf[:LIB_TERMCTL] = false
	# 仮設定
	Reish.const_set(:WCONTINUED, 8)
	def Reish::wifscontinued?(st) 
	  st.to_i == 0xffff
	end
      end

      @term_ctl = nil

      @backup_tcpgrp = nil
      if @io.tty? && Reish::conf[:LIB_TERMCTL]
	@term_ctl = true

	@backup_tcpgrp = Reish::tcgetpgrp(STDIN)
	puts "Backup TCPGRP: #{@backup_tcpgrp}" if Reish::debug_jobctl?
	@tcpgrp = Process.pid
	Reish::tcsetpgrp(STDIN, @tcpgrp)
      end

      @process_monitor = ProcessMonitor.new(@term_ctl)
      @process_monitor.start_monitor

      trap(:SIGINT) do
	signal_handle
      end

      trap(:SIGTSTP) do
	signal_handle(:TSTP)
      end

#      trap(:TTIN, :IGNORE)
      trap(:TTOU, :IGNORE)

      trap(:SIGCHLD) do
	@process_monitor.accept_sigchild
      end
    end

    attr_reader :process_monitor

    def term_ctl?; @term_ctl; end

    def set_ctlterm(pid)
      return unless @term_ctl

      unless pid
	pid = @tcpgrp
      end
      Reish::tcsetpgrp(@io.real_io, pid)
    end
  end
end
