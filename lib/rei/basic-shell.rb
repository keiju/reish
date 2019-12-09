# coding: utf-8
n#
#   basic-shell.rb - 
#   	Copyright (C) 1996-2019 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

require "rei/exenv"
require "rei/job-controller"
require "rei/input-method"
require "rei/inspector"

module REI

  PromptSet = {
    FULL: proc{|exenv, line_no, indent, ltype, continue|
      base = "#{exenv.ap_name}##{exenv.env["USER"]}@#{exenv.hostname}(#{exenv.main.class}):#{exenv.ppwd}:#{line_no}:#{indent}"
      if ltype
	base+ltype+" "
      elsif continue
	base+"? "
      else
	base+"> "
      end
    },
    FULL2: proc{|exenv, line_no, indent, ltype, continue|
      base = "#{exenv.ap_name}##{exenv.env["USER"]}@#{exenv.hostname}(#{exenv.main.class})\n#{exenv.ppwd}:#{line_no}:#{indent}"
      if ltype
	base+ltype+" "
      elsif continue
	base+"? "
      else
	base+"> "
      end
    },
    STANDARD: proc{|exenv, line_no, indent, ltype, continue|
      base = "#{exenv.ap_name}(#{exenv.main.class}):#{exenv.ppwd}:#{line_no}:#{indent.size}"
      if ltype
	base+ltype+" "
      elsif continue
	base+"? "
      else
	base+"> "
      end
    },
    BASH: proc{|exenv, line_no, indent, ltype, continue|
      base = "#{exenv.env["USER"]}@#{exenv.hostname}:#{exenv.ppwd}"
      if ltype
	base+ltype+" "
      elsif continue
	base+"? "
      else
	base+"$ "
      end
    },
    IRB: proc{|exenv, line_no, indent, ltype, continue|
      base = "#{exenv.ap_name}(#{exenv.main.class}):#{line_no}:#{indent.size}"
      if ltype
	base+ltype+" "
      elsif continue
	base+"? "
      else
	base+"> "
      end
    },
  }

  class BasicShell

    def BasicShell::inherited(sub)
      sub.instance_eval do
        @CONF = Conf.new
        @COMP = {}
        @COMP[:INPUT_METHOD] = {}
      end
    end

    def BasicShell::start(ap_path = nil)
      $0 = File::basename(ap_path, ".rb") if ap_path
      setup(ap_path)

      sh = create_main_shell
      const_set(:MAIN_SHELL, sh)
      sh.start
    end

    #Shell.create_main_shell

    def BasicShell::setup(ap_path)
      init_core(ap_path)

      init_error
      init_config(ap_path)
      parse_opts
      run_config if @CONF[:RC]
    end

    def BasicShell::init_core(ap_path)
      @CORE = Core.new(ap_path)
      const_set(:CORE, @CORE)
    end

    def BasicShell.conf
      @CONF
    end

    def BasicShell.core_conf
      @CORE.conf
    end

    def BasicShell.comp
      @COMP
    end

    def initialize(input_method = nil)

      @io = nil
      @lex = create_lex

      @job_controller = JobController.new(self)

      @exenv = Exenv.new(self, self.class.conf)
      initialize_input_method(input_method)

      @signal_status_mx = Mutex.new
      @signal_status = :IN_SHELL

      @current_input_unit = nil

    end

    attr_reader :exenv
    attr_reader :io
    attr_reader :lex
    attr_reader :job_controller

    def initialize_input_method
    end

    def create_lex
      REI::Fail NotImplementedError, "create_lex"
    end

    def start
      @lex.set_prompt do |ltype, indent, continue, line_no|
	@io.line_no = line_no if @io.kind_of?(ReidlineInputMethod)
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
	catch(:SHELL_EXIT) do
	  eval_input
	end
      ensure
      end
    end

    def eval_input
      REI::Fail NotImplementedError, "eval_input"
    end

    def input_unit
      REI::Fail NotImplementedError, "input_unit"
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
	  STDERR.syswrite "\nabort!!\n" if verbose?
	  exit
	end
	case @signal_status
	when :IN_INPUT
	  STDERR.syswrite "^C\n"
	  raise Interrupt
	when :IN_EVAL
	  shell_abort(self)
	when :IN_LOAD
	  shell_abort(self, LoadAbort)
	when :IN_SHELL
	  # ignore
	else
	  # ignore other cases as well
	end
      when :TSTP
	case @signal_status
	when :IN_EVAL
	  STDERR.syswrite "^Z\n"
	  shell_tstp(self)
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

    def shell_exit(irb, ret)
      throw :REISH_EXIT, ret
    end

    def shell_abort(irb, exception = Abort)
      @job_controller.raise_foreground_job  exception, "abort then interrupt!!"
    end

    def shell_tstp(shell)
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
	STDERR.syswrite "caught SIGCHLD\n" if Reish::debug_jobctl?
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


