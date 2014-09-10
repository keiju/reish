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

  @CONF={}

  def Reish::start(ap_path = nil)
    sh = Shell.new
    @CONF[:MainShell] = sh
    sh.start
  end
end

