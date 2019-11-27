#
#   reirb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

require "reirb"

if __FILE__ == $0
  Reirb.start(__FILE__)
else
  # check -e option
  if /^-e$/ =~ $0
    Reirb.start(__FILE__)
  else
    Reirb.setup(__FILE__)
  end
end

