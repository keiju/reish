#
#   reish.rb - 
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

require "reish/init-reish"
require "reish/locale"
require "reish/shell"

module Reish

  INSPECT_LEBEL = 1

  @CONF={}
  def Reish.conf
    @CONF
  end

  def Reish.conf_tempkey(prefix = "__Reish__", postfix = "__", &block)
    begin
      s = Thread.current.__id__.to_s(16).tr("-", "M")
      key = (prefix+s+postfix).intern
    
      block.call key
    ensure
      @CONF.delete(key)
    end
  end

  def Reish::start(ap_path = nil)
    $0 = File::basename(ap_path, ".rb") if ap_path
    Reish.setup(ap_path)

    if @CONF[:SCRIPT]
      sh = Shell.new(@CONF[:SCRIPT])
    else
      sh = Shell.new
    end

    @CONF[:REISH_RC].call(irb.context) if @CONF[:REISH_RC]
    @CONF[:MainShell] = sh
    sh.start
  end

  DefaultEncodings = Struct.new(:external, :internal)
  class << Reish
    private
    def set_encoding(extern, intern = nil)
      verbose, $VERBOSE = $VERBOSE, nil
      Encoding.default_external = extern unless extern.nil? || extern.empty?
      Encoding.default_internal = intern unless intern.nil? || intern.empty?
      @CONF[:ENCODINGS] = IRB::DefaultEncodings.new(extern, intern)
      [$stdin, $stdout, $stderr].each do |io|
	io.set_encoding(extern, intern)
      end
      @CONF[:LC_MESSAGES].instance_variable_set(:@encoding, extern)
    ensure
      $VERBOSE = verbose
    end
  end
end

