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
	@indents = []
      end

      attr_reader :buffer
      attr_reader :prompts
      attr_reader :indents

      def_delegator :@buffer, :size
      def_delegator :@buffer, :[]
      def_delegator :@buffer, :each
      def_delegator :@buffer, :last

      def indent_width(row)
	@indents[row] * 2
      end

      def each_with_prompt(&block)
	@buffer.zip(@prompts, @indents) do |l, p, i|
	  p = "" unless p
	  i = 0 unless i
	  block.call(l, p, i)
	end
      end

      def contents
	@buffer.join("\n")
      end

      def contents_to(row, col)
	if row > 0
	  contents = @buffer[0..row-1].join("\n")
	  contents.concat "\n"
	else
	  contents = ""
	end
	contents.concat @buffer[row][0..col]
	contents
      end

      def last_word(row, col)
ttyput "LW:0"
ttyput row, col
ttyput @buffer
	case @buffer[row][col]
	when nil
ttyput "LW:1"
	  s = @buffer[row].rindex(/[^[:word:]]/, col) || -1
	  @buffer[row][s+1..-1]
	when /[[:word:]]/
ttyput "LW:2"
	  s = @buffer[row].rindex(/[^[:word:]]/, col) || -1
	  e = @buffer[row].index(/[^[:word:]]/, col) || @buffer[row].size
ttyput s, e
	  @buffer[row][s+1..e-1]
	else
ttyput "LW:3"
	  e = @buffer[row].rindex(/[^[:word:]]/, col) || @buffer[row].size
	  s = @buffer[row].rindex(/[^[:word:]]/, col) || -1
	end
      end

      def empty?
	@buffer.size == 1 && @buffer.first.empty?
      end

      def eol?(row, col)
	@buffer[row].size == col
      end

      def end_of_buffer?(row, col)
	@buffer.size - 1 == row && @buffer.last.size == col
      end

      def index(pat, row=0, col=0)
	idx = @buffer[row].index(pat, col)
	return [row, idx] if idx
	row += 1
	while row < @buffer.size
	  idx = @buffer[row].index(pat)
	  return [row, idx] if idx
	  row += 1
	end
	return nil
      end
      alias re_search_forward index

      def rindex(pat, row = nil, col = nil)
	unless row
	  row = @buffer.size - 1
	end
	unless col
	  col = @buffer[row].size - 1
	end

	idx = @buffer[row].rindex(pat, col)
	return [row, col] if idx
	row -= 1
	while row < 0
	  idx = @buffer[row].rindex(pat)
	  return [row, idx] if idx
	  row -= 1
	end
	return nil
      end
      alias re_search_backward rindex

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
	if eol?(row, col)
	  @buffer.insert(row + 1, "")
	  changed
	  notify_observers(:insert_line, row)
	  changed
	  notify_observers(:prompt, row+1)
	else
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

      def set_prompt(idx, prompt, indent = nil)
	@prompts[idx] = prompt
	unless indent
	  if idx >= 1
	    indent = @indents[idx-1]
	  else
	    indent = 0
	  end
	end
	@indents[idx] = indent
	changed
	notify_observers(:prompt, idx)
      end

      def set_indent(idx, indent)
	set_prompt(idx, @prompts[idx], indent)
      end
    end
  end
end
  
