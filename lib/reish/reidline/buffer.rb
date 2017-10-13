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
	@buffer = lines.collect{|l| l.chomp}

	@prompts = []
#100.times{|i| @prompts.push "#{i}:#{2**rand(10)}> "}
      end

      attr_reader :prompts
      attr_reader :buffer

      def_delegator :@buffer, :size
      def_delegator :@buffer, :[]
      def_delegator :@buffer, :each
      def_delegator :@buffer, :last

      def each_with_prompt(&block)
	@buffer.zip(@prompts) do |l, p|
	  p = "" unless p
	  block.call(l, p)
	end
      end

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

      def end_of_buffer?(row, col)
	@buffer.size - 1 == row && @buffer.last.size == col
      end

      def insert(row, col, str)
	@buffer[row][col,0] = str
	changed
	notify_observers(:insert, row, col, str.size)
      end

      def delete(row, col)
	@buffer[row].slice!(col, 1)
#	if @buffer[row].size == 0 && @buffer.size > 1
#	  @buffer.slice!(row)
#	end
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
	  changed
	  notify_observers(:prompt, row+1)
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
	  if @buffer.size > row + 1
	    @buffer.slice!(row, 1)
	    changed
	    notify_observers(:delete_line, row)
	  else
	    return false
	  end
	else
	  @buffer[row].slice!(col..-1)
	  changed
	  notify_observers(:delete_eol, row, col)
	end
	true
      end

      def set_prompt(idx, prompt)
	@prompts[idx] = prompt
	changed
	notify_observers(:prompt, idx)
      end
    end
  end
end

