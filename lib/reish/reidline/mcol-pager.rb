#
#   lam-buffer.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "reish/reidline/message-pager"

module Reish
  class Reidline
    class MColPager<MessagePager

      def initialize(view, ary = [])
	super

	@cols = nil
	@col_widths = []
      end

      attr_reader :col_widths

#      def push(ary)
#	@buffer.push ary
#      end

      def col_width(idx)
	return @col_widths[idx] unless @col_widths.empty?
	
	@buffer.each do |l|
	  l.each_with_index do |e, i|
	    @col_widths[i] = @col_widths[i] && e &&
	      e < @col_widths[i]  ? e : @col_widths[i]
	  end
	end
	@col_widths[idx]
      end

      def line(idx)
	return nil if idx >= size
	
	str = ""
	@buffer[idx].each_with_index do |e, i|
	  str.concat format("%-*s", @col_widths[i], e)
	end

	str[0, win_width]
      end


      def inspect
	"#<MColPager: @view=#{@view} @cols=#{@cols} @col_width=#{@col_width} @buffer=#{@buffer.inspect}>"
      end

    end
  end
end



	
	

      
