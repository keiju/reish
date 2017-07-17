#!/usr/local/bin/ruby
#
#   reish/exenv.rb - execute enviromnent
#   	Copyright (C) 2014-2017 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

require "reish/mainobj"

module Reish
  class Exenv

    VOID_VALUE = Object.new

    def initialize(shell, conf, bind: VOID_VALUE, main: VOID_VALUE)
      @shell = shell

      @ap_name = Reish.conf[:AP_NAME]
      @src_path = "(" + @ap_name + ")"

      @prompt = Reish.conf[:PROMPT]
      self.display_mode = Reish.conf[:DISPLY_MODE]

      @ignore_sigint = Reish.conf[:IGNORE_SIGINT]
      @ignore_eof = Reish.conf[:IGNORE_EOF]

      @back_trace_limit = Reish.conf[:BACK_TRACE_LIMIT]

      @use_readline = Reish.conf[:USE_READLINE]
      @completion = Reish.conf[:COMPLETION]

      init_bindmain(bind: bind, main: main)

      @pwd = Dir.pwd
      @env = ENV
      self.path = ENV["PATH"]

      @home = @env["HOME"]
      @hostname = nil

      @verbose = Reish.conf[:VERBOSE]
      @display_comp = Reish.conf[:DISPLAY_COMP]
      @debug_input = Reish.conf[:DEBUG_INPUT]
      self.yydebug = Reish::conf[:YYDEBUG]

      Reish.conf[:REISH_RC].call(self) if Reish.conf[:REISH_RC]
    end

    attr_reader :shell
    attr_accessor :ap_name
    attr_accessor :src_path

    def hostname
      @hostname = `hostname`.chomp unless @hostname
      @hostname
    end

#    def user
#      @user = @env["USER"] unless @user
#      @user
#    end

    attr_reader :home
    
    def home=(val)
      @home = val
      @env["HOME"] = home
    end

    attr_accessor :prompt

    attr_reader :use_readline
    alias use_readline? use_readline

    attr_reader :completion
    alias completion? completion

    attr_reader :pwd

    def ppwd
      if @pwd[0..@home.size-1] == @home
	"~"+@pwd[@home.size..-1]
      else
	@pwd
      end
    end

    def chdir(path)
      @pwd = path
      
      rehash if @have_relative_path
    end

    def jobs
      @shell.job_controller.jobs
    end
    
    def fg(opt=nil)
      @shell.job_controller.fg opt
    end

    attr_reader :env

    #
    attr_reader :display_mode
    attr_reader :display_method

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

    attr_reader :path
    def path=(path)
      case path
      when String
	@path = path.split(":")
      when Array
	@path = path
      else
	raise TypeError
      end

      @shell.rehash

      if @env.equal?(ENV)
	@env = @env.to_hash
      end

      @env["PATH"] = @path.join(":")

      @have_relative_path = @path.find{|p| %r|^.\/| =~ p}
    end


    attr_accessor :ignore_eof
    alias ignore_eof? ignore_eof

    attr_accessor :ignore_sigint
    alias ignore_sigint? ignore_sigint

    attr_accessor :back_trace_limit

    attr_accessor :verbose
    alias verbose? verbose

    attr_reader :binding
    attr_reader :main

    def init_bindmain(bind: VOID_VALUE, main: VOID_VALUE)
      if bind != VOID_VALUE
	@binding = bind
      elsif Reish.conf[:SINGLE_REISH]
	@binding = TOPLEVEL_BINDING
      else
	case Reish.conf[:BINDING_MODE]
	when 0	# binding in proc on TOPLEVEL_BINDING
	  @binding = eval("proc{binding}.call",
		      TOPLEVEL_BINDING,
		      __FILE__,
		      __LINE__)

	when 1	# binding in loaded file

	  Reish.conf_tempkey("__TEMP_BINDING__") do |key|

	    require "tempfile"
	    f = Tempfile.open("reish-binding")
	    f.puts("Reish.conf[:#{key}]=binding)")
	    f.close
	    load f.path
	    @binding = Reish.conf[key]
	  end
	  
	when 2	# binding in loaded file(thread use)
	  unless defined? BINDING_QUEUE
	    require "tempfile"
	    require "thread"

	    Reish.const_set("BINDING_QUEUE", SizedQueue.new(1))
	    Thread.abort_on_exception = true
	    Thread.start do
	      f = Tempfile.open("reish-binding2")
	      f.puts("while true do Reish::BINDING_QUEUE.push binding; end")
	      f.close
	      load f.path

	      eval "load '#{f}'", TOPLEVEL_BINDING, __FILE__, __LINE__
	    end
	    Thread.pass
	  end
	  @binding = Reish::BINDING_QUEUE.pop

	when 3, nil # binging in function on TOPLEVEL_BINDING(default)
	  @binding = eval("def reish_binding; binding; end; reish_binding",
		      TOPLEVEL_BINDING,
		      __FILE__,
		      __LINE__ - 3)
	end
      end

      if main == VOID_VALUE
	@main = Main.new(self)
      else
	@main = main
      end
      
      Reish::conf_tempkey do |main_key|
	Reish.conf[main_key]=@main
	case @main
	when Module
	  @binding = eval("Reish.conf[:#{main_key}].module_eval('binding', __FILE__, __LINE__)", @binding, __FILE__, __LINE__)
	else
	  begin
	    @binding = eval("Reish.conf[:#{main_key}].instance_eval('binding', __FILE__, __LINE__)", @binding, __FILE__, __LINE__)
	  rescue TypeError
	    Reish.fail CantSetBinding, @main.inspect
	  end
	end
      end

      eval("_=nil", @binding)
    end

    attr_accessor :display_comp
    attr_accessor :debug_input

    def yydebug=(val)
      @yydebug = val
      @shell.yydebug = val
    end

    def inspect
      if Reish::INSPECT_LEBEL < 3
	
	ins = instance_variables.collect{|iv|
	  if iv == :@shell
	    "@shell=#{@shell}"
	  elsif iv == :@env
	    "@env=#{@envs}"
	  else
	    v = instance_eval(iv.id2name).inspect
	    "#{iv}=#{v}"
	  end
	}.join(", ")
	"#<Reish::Exenv: #{ins}>"
      else
	super
      end
    end


  end
end


