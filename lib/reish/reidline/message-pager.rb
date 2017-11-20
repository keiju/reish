#
#   message-pager.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "reish/reidline/ti"

module Reish
  class Reidline
    class MessagePager
      include Enumerable
      include TI

      def initialize(view, ary = [])
	@view = view
	@buffer = ary
      end

      def win_width
	@view.TERM_W
      end

      def win_height
	if @view.WIN_H
	  @view.TERM_H - @view.WIN_H - 1
	else
	  @view.TERM_H - @view.text_height - 1
	end
      end

      def empty?
	@buffer.empty?
      end

      def size
	@buffer.size
      end

      def push(str)
	@buffer.push str
      end

      def [](*args)
	@buffer[*args]
      end

      def each(&block)
	@buffer.each &block
      end

      def last
	@buffer.last
      end

      def line(idx)
	@buffer[idx]
      end

      def cat
	message_cursor_save do
	  each do |l|
	    if l == last
	      print l
	    else
	      puts l
	    end
	  end
	end
      end

      def more
	if @view.WIN_H
	  message_h = [size + 1, @view.TERM_H - @view.WIN_H].min
	else
	  message_h = [size + 1, @view.TERM_H - @view.text_height + @view.OFF_H].min
	end
	mh = message_h - 1

	message_cursor_save do
	  offset = 0
	  loop do
	    mh.times do |i| 
	      if size  == offset+i
		(mh - i).times do
		  @view.puts_eol
		end
		ti_clear_eol
		return
	      end
	      @view.puts_eol line(offset + i)
	    end
	    offset += mh

	    if line(offset)
	      unless line(offset+1)
		@view.print_eol line(offset)
		return
	      end
	    else
	      ti_clear_eol
	      ti_up if offset == mh
	      return
	    end

	    @view.print_width_winsz "CR: return, TAB: next-page, BS: back-page, or other character to pass itsself: "

	    ch = nil
	    STDIN.noecho do
	      STDIN.raw do
		ch = STDIN.getc
	      end
	    end

	    case ch
	    when "\C-m"
	      ti_delete_line
	      break
	    when "\t"
	      ti_up(mh)
	      ti_line_beg
	      next
	    when "\u007F"
	      offset -= mh*2
	      offset = 0 if offset < 0

	      ti_up(mh)
	      ti_line_beg
	      next
	    else
	      STDIN.ungetc(ch)
	      ti_delete_line
	      break
	    end
	  end
	end
      end

      def message_cursor_save(&block)
	begin
	  b_row = nil
	  b_col = nil
	  @view.instance_eval do
	    b_row = @t_row
	    b_col = @t_col
	  end

	  if @view.WIN_H && @view.WIN_H + @view.OFF_H < @view.text_height
	    t_row, t_col = @view.term_pos(@view.WIN_H + @view.OFF_H - 1, 0)
	  else
	    t_row, t_col = @view.term_pos(@view.text_height - 1, 
					  @view.instance_eval{@cache[text_height - 1].size - 1})
	  end
	  @view.cursor_move(t_row, t_col)
	  print "\n"
	  block.call
	ensure
	  if @view.WIN_H
	    h = [size, @view.TERM_H - @view.WIN_H].min
	  else
	    h = [size, @view.TERM_H - @view.text_height + @view.OFF_H ].min
	  end

	  if @view.WIN_H
	    ti_up(@view.WIN_H + @view.OFF_H + h - b_row - 1)
	  else
	    ti_up(@view.text_height + h - b_row - 1)
	  end
	  ti_hpos(b_col)
	  @view.instance_eval do
	    @t_row = b_row
	    @t_col = b_col
	  end
#	reset_cursor_position
	end
      end


      def inspect
	"#<Pager: @view=#{@view} @buffer=#{@buffer.inspect}>"
      end

    end
  end
end



