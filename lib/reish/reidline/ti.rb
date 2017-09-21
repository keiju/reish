#
#   editor/ti.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "io/console"
require "terminfo"

module Reish
  class Reidline
    module TI

      def ti_winsize
	IO.console.winsize
#      [tictl("li"), tictl("cols")]
      end

#       # VT100 only!!
#       def ti_cursor_pos
# #puts "CP IN"
# 	STDIN.noecho do
# 	  STDOUT.write "\e[6n"
# 	  pos = []
# 	  tmp = ""
# 	  while c = STDIN.getch
# #puts "I"
# 	    case c
# 	    when /[0-9]/
# 	      tmp.concat c
# 	    when "R", ";"
# 	      pos.push tmp.to_i - 1
# 	      tmp = ""
# 	      break if c == "R"
# 	    end
# 	  end
# #puts "CP OUT"
# #puts pos
# 	  return *pos
# 	end
#       end

      def tictl(*args)
	TermInfo.control(*args)
      end

#      def ti_cursor_position(row, col)
#	tictl("cup", row, col)
#      end
     
      def ti_up(c = 1)
	if c == 1
	  tictl("cuu1")
	else
	  tictl("cuu", c)
	end
      end

      def ti_down(c = 1)
	if c == 1
	  tictl("cud1")
	else
	  tictl("cud", c)
	end
      end

      def ti_right(c = 1)
	if c == 1
	  tictl("cuf1")
	else
	  tictl("cuf", c)
	end
      end
      alias ti_forw ti_right

      def ti_left(c = 1)
	if c == 1
	  tictl("cub1")
	else
	  tictl("cub", c)
	end
      end
      alias ti_back ti_left

      def ti_vmove(c)
	if c > 0
	  ti_down(c)
	elsif c < 0
	  ti_up(-c)
	end
      end

      def ti_hmove(c)
	if c > 0
	  ti_forw(c)
	elsif c < 0
	  ti_back(-c)
	end
      end

      def ti_move(h, w)
	ti_vmove(h)
	ti_hmove(w)
      end

      def ti_save_position(&block)
	tictl("sc")
	if block
	  restore = true
	  begin
	    restore = block.call
	  ensure
	    tictl("rc") if restore
	  end
	end
      end
      alias ti_save_pos ti_save_position

      def ti_ins_mode(&block)
	tictl("smir")
	if block
	  begin
	    block.call
	  ensure
	    tictl("rmir")
	  end
	end
      end

#      def ti_insert_line
#	tictl("il1")
#      end

      def ti_delete_line
	tictl("dl")
      end

      def ti_clear_eol
	tictl("el")
      end

      def ti_line_pos(h)
	tictl("hpa", h)
      end
      
      def ti_line_beg
	tictl("hpa", 0)
      end

      def ti_del
	tictl("dch")
      end

#      def ti_scroll_up
#	tictl("indn")
#      end

#      def ti_scroll_down
#	tictl("rin")
#      end

      def ti_clear
	tictl("clear")
      end
    end
  end
end

