#
#   editor/buffer.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "observer"
require 'forwardable'
module Reish

  class Reidline
    class Buffer
      extend Forwardable

      include Enumerable
      include Observable

      def initialize(lines = ["\n"])
	@buffer = lines.collect{|l| l[-1] = ""}
      end

      def_delegator :@buffer, :size
      def_delegator :@buffer, :[]
      def_delegator :@buffer, :each
      def_delegator :@buffer, :last

      def contents
	@buffer.join("\n")
      end

      def empty?
#ttyput @row, @buffer[@row]
	@buffer.size == 1 && @buffer.first.empty?
      end

      def eol?(row, col)
	@buffer[row].size == col
      end

      def insert(row, col, str)
	@buffer[row][col,0] = str
	changed
	notify_observers(:insert, row, col, str.size)
      end

      def delete(row, col)
	@buffer[row].slice!(col, 1)
	if @buffer[row].size == 0 && @buffer.size > 1
	  @buffer.slice!(row)
	end
	changed
	notify_observers(:delete, row, col)
      end

      def insert_cr(row, col)
#ttyput "IC:0"
	if eol?(row, col)
#ttyput "IC:1"
	  @buffer.insert(row + 1, "")
	  changed
	  notify_observers(:insert_line, row)
	else
#ttyput "IC:2"
	  sub = @buffer[row].slice!(col..-1)
	  @buffer.insert(row + 1, sub)
	  changed
	  notify_observers(:split_line, row, col)
	end
      end

      #前行と結合
      def join_line(row)
	len = @buffer[row].size
	col = @buffer[row-1].size
	@buffer[row-1].insert(-1, @buffer[row])
	@buffer.slice!(row)

	changed
	notify_observers(:join_line, row-1, col, len)
#	notify_observers(:delete_line, row)
#	changed
#ttyput "INSERT", row-1, col
#	notify_observers(:insert, row-1, col, len)
      end

      def kill_line(row, col)
	if @buffer[row] == ""
	  @buffer.slice!(row, 1)
	  changed
	  notify_observers(:delete_line, row)
	else
	  @buffer[row].slice!(col..-1)
	  changed
	  notify_observers(:delete_eol, row, col)
	end
      end
    end
  end
end

