#
#   init-reish.rb - 
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

require "optparse"

module Reish
  
  # initialize config
  def Reish.setup(ap_path)
    Reish.init_config(ap_path)
    Reish.init_error
    Reish.parse_opts
#    Reish.run_config
#    Reish.load_modules

#    unless @CONF[:PROMPT][@CONF[:PROMPT_MODE]]
#      Reish.fail(UndefinedPromptMode, @CONF[:PROMPT_MODE])
#    end
  end

  def Reish.init_config(ap_path)
    # default configurations
    unless ap_path and @CONF[:AP_NAME]
      ap_path = File.join(File.dirname(File.dirname(__FILE__)), "reish.rb")
    end
    @CONF[:AP_NAME] = File::basename(ap_path, ".rb")

    @CONF[:REISH_NAME] = "reish"
    @CONF[:REISH_LIB_PATH] = File.dirname(__FILE__)

    @CONF[:RC] = true
    @CONF[:LOAD_MODULES] = []
    @CONF[:REISH_RC] = nil

    @CONF[:USE_READLINE] = false unless defined?(ReadlineInputMethod)
    @CONF[:DISPLY_MODE] = true

    @CONF[:IGNORE_SIGINT] = true
    @CONF[:IGNORE_EOF] = false
    @CONF[:ECHO] = nil

    @CONF[:LOCALE] = Locale.new

    @CONF[:EVAL_HISTORY] = nil
    @CONF[:SAVE_HISTORY] = nil

    @CONF[:VERBOSE] = nil
    @CONF[:DISPLY_COMP] = true
    @CONF[:BACK_TRACE_LIMIT] = 16
    #  @CONF[:YYDEBUG] = false
    @CONF[:YYDEBUG] = true
    #  @CONF[:DEBUG_INPUT] = false
    @CONF[:DEBUG_INPUT] = true

    @CONF[:AT_EXIT] = []
    
    @CONF[:DEBUG_LEVEL] = 1
  end

  def Reish.init_error
    @CONF[:LOCALE].load("reish/error.rb")
  end

  def Reish.parse_opts
    opt = OptionParser.new do |opt|
      opt.on("-c string"){|v| @CONF[:OPT_C] = v}
      opt.on("-v", "--verbose"){|v| @CONF[:OPT_VERBOSE] = v == true ? 1 : v.to_i}
    end
    opt.parse!(ARGV)
  end
end
