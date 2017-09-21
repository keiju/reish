#
#   editor/editor.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "reish/reidline/buffer"
require "reish/reidline/term-view"
require "reish/reidline/key-handler"

module Reish

  class Reidline
    class Editor

      def initialize(buffer = nil)
	@view = TermView.new(self)

	@move_cursor_nest = 0

	@exit = nil

	init_keys
#	init_more_keys
	
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
	  ["\t", method(:key_tab)],
	  ["\r", method(:key_cr)],
	  ["\u0003", method(:ctl_c)],
	  ["\C-l", method(:clear)],
	]
	@handler.def_default method(:insert)
      end

      attr_reader :buffer
      attr_reader :c_row
      attr_reader :c_col

      def set_buffer(buffer = nil)
	unless buffer
	  buffer = Buffer.new
	end
	@buffer = buffer

	@c_row = @buffer.size - 1
	@c_col = @buffer.last.size

	@view.change_buffer
      end

      def set_cmpl_proc(&block)
	@cmpl_proc = block
      end

      def update_cursor_position
	@c_row = @buffer.size - 1
	@c_col = @buffer.last.size
	return @c_row, @c_col
      end

      def gets
	@exit = false
	until @exit
	  @handler.dispatch(STDIN)
	end
	@buffer.contents
      end

      def message(str)
	@view.message(str)
      end

      def normalize_cursor
	move_cursor do
	  if @c_col > @buffer[@c_row].size
	    @c_col = @buffer[@c_row].size
	  end
	end
      end

      def move_cursor(&block)
	@move_cursor_nest += 1
	begin
	  b_row = c_row
	  b_col = c_col
	  block.call
	ensure
#	  if @move_cursor_nest == 1 && (b_row != @c_row || b_col != @c_col)
	  if (b_row != @c_row || b_col != @c_col)
	    @view.cursor_reposition(b_row, b_col)
	  end
	  @move_cursor_nest -= 1
	end
      end

      def cursor_up(*args, update: true)
	move_cursor do
	  @c_row -= 1
	  if @c_row < 0
	    @c_row = 0
	  end
	end
      end

      def cursor_down(*args, update: true)
	move_cursor do
	  @c_row += 1
	  if @c_row >= @buffer.size
	    @c_row = @buffer.size - 1
	  end
	end
      end

      def cursor_right(*args, update: true)
	move_cursor do
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
	end
      end

      def cursor_left(*args, update: true)
	move_cursor do
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
	end
      end

      def cursor_end_of_line(update: true)
	move_cursor do
	  @c_col = @buffer.last.size - 1
	end
      end
      alias cursor_eol cursor_end_of_line

      def cursor_end_of_buffer(update: true)
	move_cursor do
	  @c_row = @buffer.size - 1
	  @c_col = @buffer.last.size - 1
	end
      end
      alias cursor_eob cursor_end_of_buffer

      def key_bs(*args)
	move_cursor do
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
      end

      def key_cr(*args)
	move_cursor do
	  @view.message_clear
	  normalize_cursor
	  @buffer.insert_cr(@c_row, @c_col)
	  @c_col = 0
	  cursor_down
	end
	if @c_row == @buffer.size - 1
	  @exit = true
	end
      end

      def ctl_c(*args)
	normalize_cursor
	cursor_end_of_buffer
	Process.kill :INT, $$
      end

      def clear(*args)
	@view.clear_display
      end

      def insert(io, chr)
	move_cursor do
	  normalize_cursor
	  @buffer.insert(@c_row, @c_col, chr)
	  @c_col += chr.size
	end
      end

      def key_tab(*args)
	candidates = @cmpl_proc.call(@buffer.contents)
	return if candidates.nil? || candidates.empty?

	if candidates.size > 1
	  message candidates.join("\n")
	else
	  move_cursor do
	    word = candidates.first
	    idx = -1
	    while idx = @buffer[@c_row].rindex(word[0], idx)
	      sublen = @buffer[@c_row].size - idx
	      if @buffer[@c_row][idx..-1] == word[0, sublen]
		#	      sublen.times{@buffer.delete(@c_row, idx)}
		sublen.times{key_bs}
		@buffer.insert(@c_row, idx, word)
		@c_col += word.size
		break
	      else
		idx -= 1
	      end
	    end
	  end
	end
      end

#       def init_more_keys
# 	@handler.def_default method(:insert)

# 	@more = KeyHandler.new
# 	@handler.def_handler "\t", &method(:more_more)
# 	@handler.def_default &method(:more_exit)
#       end

#       def more(height, &block)
# 	i = 0
# 	block.call i
# 	ret = @handler.dispatch(STDIN)
#       end

#       def more_more(

    end
  end
end

def ttyput(*args)
  str = args.collect{|arg| arg.inspect}.join("\n")
  system("echo '#{str}' > /dev/pts/0")
end

if $0 == __FILE__

  editor = Reish::Editor::Editor.new
#  puts "START"
  editor.start
  p editor.buffer.contents
end
