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

      def more
	if @view.WIN_H
	  message_h = @view.TERM_H - @view.WIN_H
	else
	  message_h = @view.TERM_H - @view.text_height
	end
	mh = message_h - 1

	@view.message_cursor_save do
	  offset = 0
	  loop do
	    mh.times do |i| 
	      if size == offset+i
#		@m_buffer = self[offset..-1]
		(mh - i).times do
		  ti_clear_eol
		  @view.print_eol "\n"
		  push ""
		end
		ti_clear_eol
		push ""
		return
	      end
	      @view.puts_eol self[offset+i]
	    end
	    offset += mh

	    @view.print_width_winsz "CR: return, TAB: next-page, BS: back-page, or other character to pass itsself: "

	    ch = nil
	    STDIN.noecho do
	      STDIN.raw do
		ch = STDIN.getc
	      end
	    end

	    case ch
	    when "\C-m"
#	      @buffer = @buffer[offset-mh, mh]
	      push ""
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
#	      @m_buffer = m_buffer[offset-mh, mh]
	      push ""
	      STDIN.ungetc(ch)
	      ti_delete_line
	      break
	    end
	  end
	end
      end

      def inspect
	"#<Pager: @view=#{@view} @buffer=#{@buffer.inspect}>"
      end

    end
  end
end




