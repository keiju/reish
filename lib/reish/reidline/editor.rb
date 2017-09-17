#
#   editor/editor.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "reish/reidline/buffer"
require "reish/reidline/term-view"
require "reish/reidline/key-handler"

module Reish

  module Editor
    class Editor

      def initialize(buffer = nil)
	@view = TermView.new(self)

	@exit = nil

	init_keys
	set_buffer(buffer)
      end

      def init_keys
	@handler = KeyHandler.new
	@handler.def_handlers [
	  ["\e[A", method(:cursor_up)],
	  ["\e[C", method(:cursor_right)],
	  ["\e[B", method(:cursor_down)],
	  ["\e[D", method(:cursor_left)],
	  ["\u007F", method(:key_bs)],
#	  ["\t", method(:key_tab)],
	  ["\r", method(:key_cr)],
	  ["\u0003", method(:ctl_c)],
	]
	@handler.def_default method(:insert)
      end

      attr_reader :buffer
      attr_reader :c_row
      attr_reader :c_col

      def set_buffer(buffer)
	unless buffer
	  buffer = Buffer.new
	end
	@buffer = buffer

	@c_row = @buffer.size - 1
	@c_col = @buffer.last.size

	@view.change_buffer
      end

      def start
	@exit = false
	until @exit
	  @handler.dispatch(STDIN)
	end
      end

      def update_cursor
	@view.cursor_position(@c_row, @c_col)
      end

      def normalize_cursor
	if @c_col > @buffer[@c_row].size
	  @c_col = @buffer[@c_row].size
	end
      end

      def cursor_up(*args, update: true)
	@c_row -= 1
	if @c_row < 0
	  @c_row = 0
	end
	update_cursor if update
      end

      def cursor_down(*args, update: true)
	@c_row += 1
	if @c_row >= @buffer.size
	  @c_row = @buffer.size - 1
	end
	update_cursor if update
      end

      def cursor_right(*args, update: true)
	@c_col += 1
	if @c_col > @buffer[@c_row].size
	  @c_row += 1
	  if @c_row >= @buffer.size
	    @c_row -= 1
	    @c_col = @buffer[@c_row].size
	  else
	    @c_col = 0
	  end
	end
	update_cursor if update
      end

      def cursor_left(*args, update: true)
	@c_col -= 1
	if @c_col < 0
	  @c_row -= 1
	  if @c_row < 0
	    @c_col = 0
	    @c_row = 0
	  else
	    @c_col = @buffer[@c_row].size
	  end
	elsif @buffer[@c_row].size < @c_col
	  @c_col = @buffer[@c_row].size - 1
	end
	update_cursor if update
      end

      def cursor_end_of_line(update: true)
	@c_col = @buffer.last.size - 1
	update_cursor if update
      end
      alias cursor_eol cursor_end_of_line

      def cursor_end_of_buffer(update: true)
	@c_row = @buffer.size - 1
	@c_col = @buffer.last.size - 1
	update_cursor if update
      end
      alias cursor_eob cursor_end_of_buffer

      def key_bs(*args)
	normalize_cursor
	if @c_col == 0 && @c_row > 0
	  c_col = @buffer[@c_row-1].size
	  @buffer.join_line(@c_row)
	  @c_row -= 1
	  @c_col = c_col
	else
	  cursor_left
	  @buffer.delete(@c_row, @c_col)
	end
      end

      def key_cr(*args)
	normalize_cursor
	@buffer.insert_cr(@c_row, @c_col)
	@c_col = 0
	cursor_down
	update_cursor
      end

      def ctl_c(*args)
	normalize_cursor
	cursor_end_of_buffer
	puts ""
	@exit = true
      end

      def insert(io, chr)
	normalize_cursor
	@buffer.insert(@c_row, @c_col, chr)
	@c_col += chr.size
	update_cursor
      end
    end
  end
end

if $0 == __FILE__

def ttyput(*args)
  str = args.collect{|arg| arg.inspect}.join("\n")
  system("echo '#{str}' > /dev/pts/0")
end



  editor = Reish::Editor::Editor.new
#  puts "START"
  editor.start
  p editor.buffer.contents
end
