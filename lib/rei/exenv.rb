#
#   exenv.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

module REI
  class Exenv
    VOID_VALUE = Object.new

    def Exenv.attr_conf(name, attr=name.upcase)
      self.module_eval "def #{name}; @conf[#{attr}]; end"
    end

    def initialize(shell, conf, bind: VOID_VALUE, main: VOID_VALUE)
      @shell = shell

      @conf = Conf.new(conf)
      @src_path = "(" + self.ap_name + ")"

      init_bindmain(bind: bind, main: main)

      @pwd = Dir.pwd
      @env = ENV
      self.path = ENV["PATH"]

      @home = @env["HOME"]
      @hostname = nil

      Reish.conf[:RC_SCRIPT].call(self) if Reish.conf[:RC_SCRIPT]
    end

    attr_reader :shell
    attr_conf :ap_name
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

    attr_reader :pwd

    def ppwd
      if @pwd[0..@home.size-1] == @home
	"~"+@pwd[@home.size..-1]
      else
	@pwd
      end
    end

    def chdir(path)
      p = File.expand_path(path, @pwd)
      unless File.directory?(p)
	raise Errno::ENOENT, path
      end
      @pwd = p
      rehash if @have_relative_path
      @pwd
    end

    def jobs
      @shell.job_controller.jobs
    end
    
    def fg(opt=nil)
      @shell.job_controller.fgbg(true, opt)
    end

    def bg(opt=nil)
      @shell.job_controller.fgbg(false, opt)
    end

    attr_reader :env

    #
    attr_conf :display_mode
    attr_reader :display_method

    def display_mode=(opt)
      if i = IRB::INSPECTORS[opt]
	@conf[:DISPLAY_MODE] = opt
	@display_method = i
	i.init
      else
	case opt
	when nil
	  @conf[:DISPLAY_MODE] = true
	when /^\s*\{.*\}\s*$/
	  begin
	    inspector = eval "proc#{opt}"
	  rescue Exception
	    puts "Can't switch inspect mode(#{opt})."
	    return
	  end
	  @conf[:DISPLAY_MODE] = inspector
	when Proc
	  @conf[:DISPLAY_MODE] = REI::Inspector(opt)
	when Inspector
	  prefix = "usr%d"
	  i = 1
	  while INSPECTORS[format(prefix, i)]; i += 1; end
	  @conf[:DISPLAY_MODE] = format(prefix, i)
	  @display_method = opt
	  INSPECTORS.def_inspector(format(prefix, i), @display_method)
	else
	  puts "Can't switch inspect mode(#{opt})."
	  return
	end
      end
#      print "Switch to#{unless @inspect_mode; ' non';end} inspect mode.\n" if verbose?
      @conf[:DISPLAY_MODE]
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

    attr_reader :binding
    attr_reader :main

    def init_bindmain(bind: VOID_VALUE, main: VOID_VALUE)
      if bind != VOID_VALUE
	@binding = bind
      elsif @conf[:SINGLE_SHELL]
	@binding = TOPLEVEL_BINDING
      else
	case @conf[:BINDING_MODE]
	when 0	# binding in proc on TOPLEVEL_BINDING
	  @binding = eval("proc{binding}.call",
		      TOPLEVEL_BINDING,
		      __FILE__,
		      __LINE__)

	when 1	# binding in loaded file

	  REI::CORE.conf.temp_key("__TEMP_BINDING__") do |key|

	    require "tempfile"
	    f = Tempfile.open("reish-binding")
	    f.puts("REI::CORE.conf[:#{key}]=binding)")
	    f.close
	    load f.path
	    @binding = Reish.conf[key]
	  end
	  
	when 2	# binding in loaded file(thread use)
	  unless defined? BINDING_QUEUE
	    require "tempfile"
	    require "thread"

	    REI.const_set("BINDING_QUEUE", SizedQueue.new(1))
	    #Thread.abort_on_exception = true
	    Thread.start do
	      f = Tempfile.open("reish-binding2")
	      f.puts("while true do REI::BINDING_QUEUE.push binding; end")
	      f.close
	      load f.path

	      eval "load '#{f}'", TOPLEVEL_BINDING, __FILE__, __LINE__
	    end
	    Thread.pass
	  end
	  @binding = Reish::BINDING_QUEUE.pop

	when 3, nil # binging in function on TOPLEVEL_BINDING(default)
	  @binding = eval("def rei_binding; binding; end; rei_binding",
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
      
      REI::CORE.conf.temp_key do |main_key|
	REI::CORE.conf[main_key]=@main
	case @main
	when Main
	  @binding = @main.instance_eval{reish_binding}
	when Module
	  @binding = eval("REI::CORE.conf[:#{main_key}].module_eval('binding', __FILE__, __LINE__)", @binding, __FILE__, __LINE__)
	else
	  begin
	    @binding = eval("REI::CORE.conf[:#{main_key}].instance_eval('binding', __FILE__, __LINE__)", @binding, __FILE__, __LINE__)
	  rescue TypeError
	    REI.fail CantSetBinding, @main.inspect
	  end
	end
      end

      eval("_=nil", @binding)
    end

    attr_accessor :display_comp

    def yydebug=(val)
      @shell.yydebug = val
    end

    def inspect
      if REI::INSPECT_LEBEL < 3
	
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
	"#<REI::Exenv: #{ins}>"
      else
	super
      end
    end


  end


