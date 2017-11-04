#
#   editor/editor.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "reish/reidline/buffer"
require "reish/reidline/term-view"
require "reish/reidline/key-handler"
require "reish/reidline/history-session"
require "reish/reidline/lam-buffer"

module Reish

  class Reidline
    class Editor

      def initialize(buffer = nil)
	@view = TermView.new(self)

	@history_session = nil

	@in_move_cursor = nil

	@closed_proc = nil
	@cmpl_proc = nil

	@exit = nil

	init_keys
#	init_more_keys
	
	set_buffer(buffer)
      end

      def init_keys
	@handler = KeyHandler.new
	@handler.def_handlers [
	  ["\e\u007F", method(:delete_backword_word)],
	  ["\e[A", method(:cursor_up)],
	  ["\e[B", method(:cursor_down)],
	  ["\e[C", method(:cursor_right)],
	  ["\e[D", method(:cursor_left)],
	  ["\e<", method(:cursor_bob)],
	  ["\e>", method(:cursor_eob)],
	  ["\eb", method(:cursor_backword_word)],
	  ["\ed", method(:delete_forword_word)],
	  ["\ef", method(:cursor_forword_word)],
	  ["\ep", method(:history_prev)],
	  ["\en", method(:history_next)],

	  ["\C-a", method(:cursor_beginning_of_line)],
	  ["\C-b", method(:cursor_left)],
	  ["\C-c", method(:ctl_c)],
	  ["\C-d", method(:delete_char)],
	  ["\C-e", method(:cursor_end_of_line)],
	  ["\C-f", method(:cursor_right)],
	  ["\C-i", method(:dynamic_complete)],
	  ["\C-k", method(:kill_line)],
	  ["\C-l", method(:clear)],
	  ["\C-n", method(:cursor_down)],
	  ["\C-o", method(:open_line)],
	  ["\C-p", method(:cursor_up)],
	  ["\C-m", method(:key_cr)],

#	  ["\M-\u007F", method(:delete_backword_word)],
	  ["\M-<", method(:cursor_bob)],
	  ["\M->", method(:cursor_eob)],
	  ["\M-b", method(:cursor_backword_word)],
	  ["\M-d", method(:delete_forword_word)],
	  ["\M-f", method(:cursor_forword_word)],
	  ["\M-p", method(:history_prev)],
	  ["\M-n", method(:history_next)],


	  ["\u007F", method(:backspace)],
	]
	@handler.def_default method(:insert)
      end

      attr_reader :buffer
      attr_reader :c_row
      attr_reader :c_col

      def set_buffer(buffer = nil)
	old_buffer = @buffer
	case buffer
	when nil
	  @buffer = Buffer.new
	when String
	  @buffer = Buffer.new(buffer.split(/\n/).collect{|l| l+"\n"})
	else
	  @buffer = buffer
	end

	@c_row = @buffer.size - 1
	@c_col = @buffer.last.size

	@view.change_buffer
      end

      def closed?
	@closed_proc.call(@buffer.buffer)
      end

      def set_closed_proc(&block)
	@closed_proc = block
      end

      def set_cmpl_proc(&block)
	@cmpl_proc = block
      end

      def set_prompt(line_no, prompt, indent = nil)
	@buffer.set_prompt(line_no, prompt, indent)
	cursor_reposition
      end

      def set_indent(line_no, indent)
	@buffer.set_indent(line_no, indent)
	cursor_reposition
      end

#      def sync_cursor_position
#	@c_row = @buffer.size - 1
#	@c_col = @buffer.last.size
#	return @c_row, @c_col
#      end

      def get_lines(prompt = nil)
	reset_history_session
	set_prompt(0, prompt) if prompt
	contents = nil
	begin
	  @exit = false
	  until @exit
	    begin
	      @handler.dispatch(STDIN)
	    rescue Reidline::KeyHandler::UnboundKey=>exc
	      message(exc.message)
	    end
	  end
	end until closed?
	@view.clear_prompt_line
	contents = @buffer.contents
	if contents[-1] != "\n"
	  contents.concat "\n"
	end
	contents
      end

      def message(str, append: false, buffer_class: nil)
	@view.message(str, append: append, buffer_class: buffer_class)
      end

      def message_clear
	@view.message_clear
      end

      def beginning_of_line?
	@c_col == 0
      end
      alias bol? beginning_of_line?

      def end_of_line?
	@buffer.eol?(@c_row, @c_col)
      end
      alias eol? end_of_line?

      def beginning_of_buffer?
	@c_row == 0 && @c_col == 0
      end
      alias bob? beginning_of_buffer?

      def end_of_buffer?
	@buffer.end_of_buffer?(@c_row, @c_col)
      end
      alias eob? end_of_buffer?

      def current_char
	@buffer[@c_row][@c_col]
      end
      alias point_char current_char

      def re_search_forward(pat)
	ret = @buffer.re_search_forward(pat, @c_row, @c_col)
	if ret
	  @c_row, @c_col = *ret
	else
	  nil
	end
      end

      def re_search_backward(pat)
	ret = @buffer.re_search_backward(pat, @c_row, @c_col)
	if ret
	  @c_row, @c_col = *ret
	else
	  nil
	end
      end

      def normalize_cursor(update: true)
	if @c_col > @buffer[@c_row].size
	  @c_col = @buffer[@c_row].size
	end
	cursor_reposition if update
      end

      def cursor_reposition
	@view.cursor_reposition
      end

      def cursor_up(*args, update: true)
	@c_row -= 1
	if @c_row < 0
	  @c_row = 0
	  history_prev
	end
	cursor_reposition if update
      end

      def cursor_down(*args, update: true)
	@c_row += 1
	if @c_row >= @buffer.size
	  @c_row = 0
	  history_next
	end
	cursor_reposition if update
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
	cursor_reposition if update
      end
      alias cursor_forward cursor_right

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
	elsif @buffer[@c_row].size <= @c_col
	  @c_col = @buffer[@c_row].size - 1
	end
	cursor_reposition if update
      end
      alias cursor_backword cursor_left

      def cursor_beginning_of_line(*args, update: true)
	@c_col = 0
	cursor_reposition if update
      end
      alias cursor_bol cursor_beginning_of_line

      def cursor_end_of_line(*args, update: true)
	@c_col = @buffer[@c_row].size
	cursor_reposition if update
      end
      alias cursor_eol cursor_end_of_line

      def cursor_beginning_of_buffer(*args, update: true)
	@c_row = 0
	@c_col = 0

	cursor_reposition if update
      end
      alias cursor_bob cursor_beginning_of_buffer

      def cursor_end_of_buffer(*args, update: true)
	@c_row = @buffer.size - 1
	@c_col = @buffer.last.size

	cursor_reposition if update
      end
      alias cursor_eob cursor_end_of_buffer

      def cursor_backword_word(*args, update: true)
	begin
	  cursor_left(update: false)
	  break if bob?
	end until /\w/ =~ current_char
	begin
	  cursor_left(update: false)
	  if bol?
	    cursor_reposition if update
	    return
	  end
	end until /\W/ =~ current_char
	cursor_right(update: update)
      end
      alias cursor_left_word cursor_backword_word

      def cursor_forword_word(*args, update: true)
	unless re_search_forward(/\w/)
	  cursor_end_of_buffer(update: update)
	  return
	end
	unless re_search_forward(/\W|$/)
	  cursor_end_of_buffer(update: update)
	  return
	end
	cursor_reposition if update
      end
      alias cursor_right_word cursor_forword_word

      def insert(io, chr)
	normalize_cursor
	@buffer.insert(@c_row, @c_col, chr)
	@c_col += chr.size
	cursor_reposition
      end

      def backspace(*args)
	normalize_cursor
	if @c_col == 0 && @c_row > 0
	  c_col = @buffer[@c_row-1].size
	  cursor_reposition
	  @buffer.join_line(@c_row)
	  @c_row -= 1
	  @c_col = c_col
	  cursor_reposition
	else
	  cursor_left
	  cursor_reposition
	  @buffer.delete(@c_row, @c_col)
	end
      end

      def delete_char(io, chr)
	if @buffer.empty?
	  insert(io, chr)
	  @exit = true
	elsif @buffer.end_of_buffer?(@c_row, @c_col)
	  message("end of buffer")
	elsif @c_col == @buffer[@c_row].size
	  @buffer.join_line(@c_row + 1)
	else
	  @buffer.delete(@c_row, @c_col)
	end
      end

      def delete_backword_word(*args)
	normalize_cursor
	f_row = @c_row
	f_col = @c_col

	cursor_backword_word
	if  f_row == @c_row && f_col == @c_col
	  return
	end
	t_row = @c_row
	t_col = @c_col
	@c_row = f_row
	@c_col = f_col
	
	until t_row == @c_row && t_col == @c_col
	  backspace
	end
      end

      def delete_forword_word(*args)
	normalize_cursor
	f_row = @c_row
	f_col = @c_col

	cursor_forword_word
	if  f_row == @c_row && f_col == @c_col
	  return
	end
	
	until f_row == @c_row && f_col == @c_col
	  backspace
	end
      end

      def open_line(*args)
	key_cr
	cursor_left
      end

      def kill_line(*args)
	unless @buffer.kill_line(@c_row, @c_col)
	  message("end of buffer")
	end
      end

      def key_cr(*args)
	normalize_cursor
	message_clear
	@buffer.insert_cr(@c_row, @c_col)
	@c_col = 0
	cursor_reposition
	cursor_down
	
	if @c_row == @buffer.size - 1
	  @exit = true
	else
	  closed?
	end
      end

      def ctl_c(*args)
	normalize_cursor
	message_clear
	cursor_end_of_buffer
	cursor_reposition
#	puts "\ninput abort!"
	Process.kill :INT, $$
      end

      def clear(*args)
	closed?
	@view.clear_display
      end

      def dynamic_complete(*args)
	message_clear

	unless @cmpl_proc
	  message("not defined completion procedure")
	  return
	end

	candidates, token = @cmpl_proc.call(@buffer.contents_to(@c_row, @c_col)) 
	return if candidates.nil? || candidates.empty?

	if candidates.size > 1
	  i = -1
	  message candidates.sort, buffer_class: LamBuffer
	else
	  word = candidates.first+" "
	  token.size.times{backspace}
	  @buffer.insert(@c_row, @c_col, word)
	  @c_col += word.size
	  cursor_reposition

# 	  idx = -1
# 	  while idx = @buffer[@c_row].rindex(word[0], idx)
# 	    sublen = @buffer[@c_row].size - idx
# 	    if @buffer[@c_row][idx..-1] == word[0, sublen]
# 		#	      sublen.times{@buffer.delete(@c_row, idx)}
# 	      sublen.times{backspace}
# 	      @buffer.insert(@c_row, idx, word)
# 	      @c_col += word.size
# 	      cursor_reposition
# 	      break
# 	    else
# 	      idx -= 1
# 	    end
# 	  end
	end
      end

      def set_history(history)
	@history_session = HistorySession.new(self, history)
      end

      def reset_history_session
	@history_session.reset
      end

      def history_prev(*args)
	@history_session.prev
      end

      def history_next(*args)
	@history_session.next
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

TTY0 = File.open("/dev/pts/0", "w")
def ttyput(*args)
  str = args.collect{|arg| arg.inspect}.join("\n")
  TTY0.puts str
#  system("echo '#{str}' > /dev/pts/0")
end

if $0 == __FILE__

  editor = Reish::Editor::Editor.new
#  puts "START"
  editor.start
  p editor.buffer.contents
end
