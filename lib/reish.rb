#
#   reish.rb - 
#   	Copyright (C) 2014-2017 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

require "reish/locale"
require "reish/init-reish"
require "reish/shell"
require "reish/completor"

module Reish

  INSPECT_LEBEL = 1

  class Abort < Exception;end

  @CONF={}
  @COMP = {}
  @COMP[:INPUT_METHOD] = {}

  def Reish.conf
    @CONF
  end

  def Reish.comp
    @COMP
  end

  def Reish::start(ap_path = nil)
    $0 = File::basename(ap_path, ".rb") if ap_path
    Reish.setup(ap_path)

    if @CONF[:OPT_C]
      im = StringInputMethod.new(nil, @CONF[:OPT_C])
      sh = MainShell.new(im)
    elsif @CONF[:OPT_TEST_CMPL]
      compl = @COMP[:COMPLETOR].new(Shell.new)
      compl.candidate(@CONF[:OPT_TEST_CMPL])
      exit
    elsif !ARGV.empty?
      f = ARGV.shift
      sh = MainShell.new(f)
    else
      sh = MainShell.new
    end
    const_set(:MAIN_SHELL, sh)

    sh.start
  end

  def Reish::active_thread?
    Thread.current[:__REISH_CURRENT_SHELL__]
  end

  def Reish::current_shell(no_exception = nil)
    sh = Thread.current[:__REISH_CURRENT_SHELL__]
    Reish.Fail NotExistCurrentShell unless no_exception || sh
    sh
  end

  def Reish::current_shell=(sh)
    Thread.current[:__REISH_CURRENT_SHELL__] = sh
  end

  def self::current_job(no_exception = nil)
    job = Thread.current[:__REISH_CURRENT_JOB__]
    Reish.Fail NotExistCurrentJob unless no_exception || job
    job
  end
  
  def self::current_job=(job)
    Thread.current[:__REISH_CURRENT_JOB__] = job
  end

  def Reish::inactivate_command_search(ifnoactive: nil, &block)
    sh = Thread.current[:__REISH_CURRENT_SHELL__]
    return ifnoactive.call if !sh && ifnoactive

    sh.inactivate_command_search &block
  end

  def Reish::conf_tempkey(prefix = "__Reish__", postfix = "__", &block)
    begin
      s = Thread.current.__id__.to_s(16).tr("-", "M")
      key = (prefix+s+postfix).intern
    
      block.call key
    ensure
      @CONF.delete(key)
    end
  end

  DefaultEncodings = Struct.new(:external, :internal)
  class << Reish
    private
    def set_encoding(extern, intern = nil)
      verbose, $VERBOSE = $VERBOSE, nil
      Encoding.default_external = extern unless extern.nil? || extern.empty?
      Encoding.default_internal = intern unless intern.nil? || intern.empty?
      @CONF[:ENCODINGS] = Reish::DefaultEncodings.new(extern, intern)
      [$stdin, $stdout, $stderr].each do |io|
	io.set_encoding(extern, intern)
      end
      @CONF[:LC_MESSAGES].instance_variable_set(:@encoding, extern)
    ensure
      $VERBOSE = verbose
    end
  end

  debug_category = [:GENERAL, :SYSTEM_COMMAND, :INPUT, :YY, :CMPL, :CMPL_YY, :JOBCTL, :FUNCTION, :LEX_STATE]
  f = 1
  debug_category.each do |cat|
    c = "DEBUG_"+cat.id2name
    const_set(c, f)
    method_name = cat.id2name.downcase
    module_eval(%{
      def Reish.debug_#{method_name}?
	@CONF[:DEBUG] & #{c} != 0
      end
      def Reish.debug_#{method_name}_on
	@CONF[:DEBUG] |= #{c}
      end
      def Reish.debug_#{method_name}_off
	@CONF[:DEBUG] &= ~#{c}
      end
    })
    f<<=1
  end

  def Reish.debug?(flag = DEBUG_GENERAL)
    @CONF[:DEBUG] & flag != 0
  end
end

class Object
  include Reish::OSSpace
end

