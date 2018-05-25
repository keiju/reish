#
#   reirb/shell.rb - 
#   	Copyright (C) 2014-2018 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

require "reirb/exenv"

require "reirb/lex"
require "reirb/job-controller"
require "reirb/process-monitor"

require "reirb/input-method"
require "irb/inspector"


module Reirb
  class Shell
    def initialize(input_method = nil)

#      @thread = Thread.current

      @io = nil

      @lex = Lex.new

      @job_controller = Reish::JobController.new(self)

      @exenv = Exenv.new(self, Reirb.conf)
      initialize_input_method(input_method)

      @signal_status_mx = Mutex.new
      @signal_status = :IN_IRB

      @current_input_unit = nil

    end

#    attr_reader :thread
    attr_reader :exenv

    attr_reader :io
    attr_reader :lex
    attr_reader :job_controller

    attr_reader :completor

    def initialize_input_method(input_method)
      case input_method
      when nil
	case @exenv.use_readline?
	when nil
	  if STDIN.tty?
	    @io = Reirb::comp[:INPUT_METHOD][:TTY].new(@exenv)
	  else
	    @io = StdioInputMethod.new(@exenv)
	  end
	when false
	  @io = StdioInputMethod.new(@exenv)
	when true
	  @io = @exenv.tty_input_method.new(@exenv)
	end
      when String
	@io = FileInputMethod.new(@exenv, input_method)
	@exenv.ap_name = File.basename(input_method)
	@exenv.src_path = input_method
      else
	@io = input_method
      end
      if @io.completable? && @exenv.completion? 
	@completor = Reirb::comp[:COMPLETOR].new(self) 
	@io.completor = @completor
      end
      if @io.respond_to?(:promptor)
	@io.promptor = proc{|line_no, indent, ltype, continue| @exenv.prompt.call(@exenv, line_no, indent, ltype, continue)}
      end
    end

    def start
      @lex.set_prompt do |ltype, indent, continue, line_no|
	@io.line_no = line_no if @io.kind_of?(Reirb::ReidlineInputMethod)
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
	catch(:REIRB_EXIT) do
	  eval_input
	end
      ensure
      end
    end

    def eval_input
      @lex.initialize_input

      loop do
#	@lex.lex_state = Lex::EXPR_BEG
	@current_input_unit = nil
	begin
	  @current_input_unit = input_unit
	rescue ParseError => exc
#	  puts exc.message
#	  @lex.reset_input
	rescue Interrupt => exc
      
	rescue => exc
	  handle_exception(exc)
	end

	break unless @current_input_unit
# 	break if Node::EOF == @current_input_unit
# 	if Node::NOP == @current_input_unit 
# 	  puts "<= (NL)" if @exenv.display_comp
# 	  next
# 	end
#	exp = @current_input_unit.accept(@codegen)
	puts "<= #{@current_input_unit}" if @exenv.display_comp

	start_job(true, @current_input_unit) do
	  eval(@current_input_unit, @exenv.binding, @exenv.src_path, @lex.prev_line_no)
	end

      end
    end

    def input_unit
      @current_input_unit = @lex.input_unit
      if Reirb::debug_input?
	puts "input: #{input}"
	puts "input_unit: #{@current_input_unit.pretty_inspect}"
      end
      @current_input_unit
    end

    def start_job(fg, exp, &block)
      @job_controller.start_job(fg, exp) do
	exc = nil
	val = nil
	begin
	  signal_status(:IN_EVAL) do
	    val = block.call
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
	  STDERR.syswrite "\nabort!!\n" if verbose?
	  exit
	end
	case @signal_status
	when :IN_INPUT
	  STDERR.syswrite "^C\n"
	  raise Interrupt
	when :IN_EVAL
	  reirb_abort(self)
	when :IN_LOAD
	  reirb_abort(self, LoadAbort)
	when :IN_IRB
	  # ignore
	else
	  # ignore other cases as well
	end
      when :TSTP
	case @signal_status
	when :IN_EVAL
	  STDERR.syswrite "^Z\n"
	  reirb_tstp(self)
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

    def reirb_exit(irb, ret)
      throw :REIRB_EXIT, ret
    end

    def reirb_abort(irb, exception = Abort)
      @job_controller.raise_foreground_job  exception, "abort then interrupt!!"
    end

    def reirb_tstp(shell)
      th = Thread.start do
	th.abort_on_exception = true
	puts "catch TSTP"
	@job_controller.suspend_foreground_job
      end
    end

  end

  class MainShell < Shell

    def initialize(input_method = nil)
      super

      begin
	require "ext/reish"
	Reirb::conf[:LIB_TERMCTL] = true
      rescue LoadError
	Reirb::conf[:LIB_TERMCTL] = false
	# 仮設定
	Reirb.const_set(:WCONTINUED, 8)
	def Reish::wifscontinued?(st) 
	  st.to_i == 0xffff
	end
      end

      @term_ctl = nil

      @backup_tcpgrp = nil
      if @io.tty? && Reirb::conf[:LIB_TERMCTL]
	@term_ctl = true

	@backup_tcpgrp = Reish::tcgetpgrp(STDIN)
	puts "Backup TCPGRP: #{@backup_tcpgrp}" if Reirb::debug_jobctl?
	@tcpgrp = Process.pid
	Reish::tcsetpgrp(STDIN, @tcpgrp)
      end

      @process_monitor = Reirb::ProcessMonitor.new(@term_ctl)
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
	STDERR.syswrite "caught SIGCHLD\n" if Reirb::debug_jobctl?
#	Thread.start do
	  @process_monitor.accept_sigchild
#	end
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
