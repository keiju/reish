#
#   lam-buffer.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "reish/reidline/messenger"

module Reish
  class Reidline
    class MColMessenger<Messenger

      def initialize(ary = [], view: view)
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
	  next unless l.kind_of?(Array)

	  l.each_with_index do |e, i|
	    s = (e&.bytesize || 0) + 1
	    @col_widths[i] = s > (@col_widths[i] || 0) ? s : @col_widths[i]
	  end
	end
	@col_widths[idx]
      end

      def line(idx)
	return nil if idx >= size
	return @buffer[idx] unless @buffer[idx].kind_of?(Array)
	
	str = ""
	@buffer[idx].each_with_index do |e, i|
	  str.concat format("%-*s", col_width(i), e)
	end

	str[0, win_width]
      end

      def inspect
	"#<MColMessenger: @view=#{@view} @cols=#{@cols} @col_width=#{@col_width} @buffer=#{@buffer.inspect}>"
      end

    end
  end
end
