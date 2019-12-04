#
#   basic-shell.rb - 
#   	Copyright (C) 1996-2019 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

module Rei
  class BasicShell

    def BasicShell::inherited(sub)
      sub.instance_eval do
        @CONF = {}
        @COMP = {}
        @COMP[:INPUT_METHOD] = {}
      end
    end

    def BasicShell::start(ap_path = nil)
      $0 = File::basename(ap_path, ".rb") if ap_path
      setup(ap_path)

      if @CONF[:OPT_C]
        im = self::StringInputMethod.new(nil, @CONF[:OPT_C])
        sh = self::MainShell.new(im)
      elsif @CONF[:OPT_TEST_CMPL]
        compl = @COMP[:COMPLETOR].new(new)
        compl.candidate(@CONF[:OPT_TEST_CMPL])
        exit
      elsif !ARGV.empty?
        f = ARGV.shift
        sh = self::MainShell.new(f)
      else
        sh = self::MainShell.new
      end
      const_set(:MAIN_SHELL, sh)

      sh.start
    end
  end

  class Core
    def active_thread?
      Thread.current[:__REI_CURRENT_SHELL__]
    end

    def current_shell(no_exception = nil)
      sh = Thread.current[:__REI_CURRENT_SHELL__]
      self.Fail NotExistCurrentShell unless no_exception || sh
      sh
    end

    def current_shell=(sh)
      Thread.current[:__REI_CURRENT_SHELL__] = sh
    end

    def current_job(no_exception = nil)
      job = Thread.current[:__REI_CURRENT_JOB__]
      self.Fail NotExistCurrentJob unless no_exception || job
      job
    end
    
    def current_job=(job)
      Thread.current[:__REI_CURRENT_JOB__] = job
    end

    
  end

  Reicore = Core.new

  DefaultEncodings = Struct.new(:external, :internal)
  class << Rei
    private
    def set_encoding(extern, intern = nil)
      verbose, $VERBOSE = $VERBOSE, nil
      Encoding.default_external = extern unless extern.nil? || extern.empty?
      Encoding.default_internal = intern unless intern.nil? || intern.empty?
      @CONF[:ENCODINGS] = Rei::DefaultEncodings.new(extern, intern)
      [$stdin, $stdout, $stderr].each do |io|
	io.set_encoding(extern, intern)
      end
      @CONF[:LC_MESSAGES].instance_variable_set(:@encoding, extern)
    ensure
      $VERBOSE = verbose
    end
  end

  def def_debug_functions(mod, debug_category)
    f = 1
    debug_category.each do |cat|
      c = "DEBUG_"+cat.id2name
      const_set(c, f)
      method_name = cat.id2name.downcase
      mod.module_eval(%{
        def debug_#{method_name}?
	    @CONF[:DEBUG] & #{c} != 0
        end
        def debug_#{method_name}_on
	    @CONF[:DEBUG] |= #{c}
        end
        def debug_#{method_name}_off
	    @CONF[:DEBUG] &= ~#{c}
        end
      })
      f<<=1
    end

    mod.module_eval{
      def debug?(flag = DEBUG_GENERAL)
        @CONF[:DEBUG] & flag != 0
      end
    }
  end
  
end


