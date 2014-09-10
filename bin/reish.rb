#
#   reish - 
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

require "reish"

if __FILE__ == $0
  Reish.start(__FILE__)
else
  # check -e option
  if /^-e$/ =~ $0
    Reish.start(__FILE__)
  else
    Reish.setup(__FILE__)
  end
end

