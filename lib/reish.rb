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
    sh = Shell.new
    @CONF[:MainShell] = sh
    sh.start
  end

end

