#
#   editor/term-viewr.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "io/console"
require "observer"

require "terminfo"

require "reish/reidline/ti"

module Reish
  class Reidline
    class TermView
      include TI

      def initialize(editor)
	@controller = editor

	@term_height, @term_width = ti_winsize

	@buffer = nil
	@cache = nil

	@cache_row = nil
	@cache_col = nil

#	@ORG_H = nil
	
	@message_h = 0
      end

      def update_cursor_position
	@controller.update_cursor_position
      end

      def text_height
	@cache.inject(0){|r, lines| r += lines.size}
      end

      def change_buffer
	if @buffer 
	  @buffer.delete_observer(self)
	end

	@buffer = @controller.buffer
	@buffer.add_observer(self)
	
#	@ORG_H, dummy = ti_cursor_pos

	redisplay cache_update: true

      end

      def cursor_position(b_row, c_row, b_col, c_col)
	
      end
			  

      def clear_display
	ti_clear
#	@ORG_H = 0
	redisplay(cache_update: true)
      end

      def redisplay(from: 0, cache_update: false)
	if cache_update
	  @cache = []
	  @buffer.each do |line|
	    @cache.push slice_width(line)
	  end
	end

	i = 0
	line_last = @cache.last.last
	@cache.each do |lines|
	  lines.each do |line|
	    next if from > i

	    if line.equal?(line_last)
	      print line
	    else
	      puts line 
	    end
	  end
	end
	update_cursor_position
      end

      def slice_width(str, width = @term_width)
	str = str.dup
	split = []
	until str.size == 0
	  s0 = str.slice!(0, width)
	  until s0.bytesize <= width
	    str.prepend s0.slice!(-1)
	  end
	  split.push s0
	end
	split.push "" if split.empty? #|| split.last.size == width
	split
      end

      def cache_col(row, col)
	line = @cache[row]
	i = 0
	until col <= line[i].size
	  col -= line[i].size
	  i += 1
	end
	if col == line[i].size && line[i+1]
	  col -= line[i].size
	  i += 1
	end
	return i, col
      end

      def term_pos(row, col)
	if @buffer[row].size < col
	  col = @buffer[row].size
	end

	h = 0
	for i in 0..(row-1)
	  h += @cache[i].size
	end

	sub_row, sub_col = cache_col(row, col)
	if sub_col > 0
	  w = @cache[row][sub_row][0..sub_col-1].bytesize
	else
	  w = 0
	end
	return h+sub_row, w
      end

      def term_rpos(row, col)
	h, w = term_pos(row, col)
	return h - @controller.c_row, w - @controller.c_col
      end

#      def cursor_position(row, col)
#	h, w = term_pos(row, col)
#	ti_cursor_position(@ORG_H+h, w)
#      end

      def cursor_move(t_row, t_col)
	c_row, c_col = term_pos(@controller.c_row, @controller.c_col)
	h = t_row - c_row
	w = t_col - c_col
	ti_move(h, w)
      end

      def cursor_reposition(b_row, b_col)
	c_row, c_col = term_pos(b_row, b_col)
	t_row, t_col = term_pos(@controller.c_row, @controller.c_col)
	h = t_row - c_row
	w = t_col - c_col
	ti_move(h, w)
      end

#       def insert_line
# 	if @ORG_H + text_height < @term_height
# #p "A"
# #p @ORG_H, text_height,  @message_h, @term_height
# 	  ti_down
# 	  ti_insert_line
# 	else
# #p "B"
# 	  ti_scroll_up
# #	  ti_up
# 	  ti_insert_line
# 	  @ORG_H -= 1
# 	end
#       end

      def update_insert(row, col, len)
	ti_save_position do
	  !insert_string_sub(row, col, @buffer[row][col, len])
	end
      end

      def insert_string_sub(row, col, str)
	insert_line_row = nil

	t_row, t_col = term_pos(row, col)
	cursor_move(t_row, t_col)

	ti_ins_mode do
	  sub_row, sub_col = cache_col(row, col)
	  @cache[row][sub_row].insert(sub_col, str)
	  print str
	  until @cache[row][sub_row].bytesize <= @term_width
	    split = slice_width(@cache[row][sub_row])
	    @cache[row][sub_row] = split.shift
	    until split.size <= 2
	      sub = split.shift
	      @cache[row].insert(sub_row, sub)
	      insert_line_row = [row, sub_row]
#	      ti_line_beg; ti_down
#	      print(sub)
	      sub_row += 1
	    end
	    sub = split.first
	    unless insert_lin_row
	      ti_down; ti_line_beg
	      print sub
	    end
	    sub_row += 1
	    @cache[row][sub_row] = "" if @cache[row][sub_row].nil?
	    @cache[row][sub_row].insert(0, sub)
	  end
	  if @cache[row][sub_row].bytesize == @term_width
	    @cache[row].push ""
	    unless insert_line_row
#	      insert_line
#	      ti_line_beg
	    else
	      insert_line_row = row, sub_row
	    end
	  end
	  redisplay(from: insert_line_row) if insert_line_row
	end
	insert_line_row
      end

      def update_delete(row, col)
ttyput row, col
	ti_save_position do
	  t_row, t_col = term_pos(row, col)

	  cursor_move(t_row, t_col)
ttyput t_row, t_col
	  sub_row, sub_col = cache_col(row, col)
	  @cache[row][sub_row].slice!(col, 1)
	  ti_del

	  until @cache[row][sub_row+1].nil? 
	    if @cache[row][sub_row].bytesize + @cache[row][sub_row+1][0].bytesize <= @term_width
	      ti_line_pos(@cache[row][sub_row].bytesize)
	      ti_ins_mode do
		print @cache[row][sub_row+1][0]
		@cache[row][sub_row].concat @cache[row][sub_row+1].slice!(0,1)
		ti_line_beg; ti_down
		ti_del
		if @cache[row][sub_row+1].size == 0
		  @cache[row].slice!(sub_row+1)
		  ti_delete_line
		end
		sub_row += 1
	      end
	    end
	  end
	  if @cache[row].empty? && @cache.size > 0
	    @cache.slice!(row)
	  end
	end
      end

      def update_insert_line(row)
	t_row, t_col = term_pos(row, @buffer[row].size)
	cursor_move(t_row, t_col)
	@cache.insert(row+1, [""])
	redisplay(from: row+1)
      end

      def update_delete_line(row)
	ti_save_position do
	  t_row, t_col = term_pos(row, 0)
	  cursor_move(t_row, t_col)
	  n = @cache[t_row].size
	  @cache.slice!(t_row)
	  n.times{ti_delete_line}
	end
      end

      def update_split_line(row, col)
	t_row, t_col = term_pos(row, col)

	cursor_move(t_row, t_col)
	
	sub_row, sub_col = cache_col(row, col)
	sub = @cache[row][sub_row].slice!(sub_col .. -1)
	ti_clear_eol
	if sub_row < @cache[row].size
	  sub.concat @cache[row].slice!(sub_row+1..-1).join
	end
	@cache.insert(row+1, [""])
	insert_string_sub(row+1, 0, sub)
	redisplay(from: row+1)
      end

      def update(id, *args)
	updater = "update_#{id.id2name}"
	if respond_to?(updater)
	  send updater, *args
	else
	  raise ArgumentError, "Unregistered id: #{id}"
	end
      end

      def move_to_message_frame
	t_row, t_col = term_pos(text_height, 0)
	cursor_move(t_row, t_col)
      end

      def message(str)
	message_clear if @message_h > 0
p @message_h
	m_buffer = []

	lines = str.split(/\n/)
	
	h = 1
	lines.each do |line|
	  ll = slice_width(line)
	  ll.each do |l|
	    m_buffer.push l
	  end
	end

	if m_buffer.size + text_height < @term_height
	  m_buffer.each do |l|
	    puts l
	  end
	else
	  message_more(m_buffer)
	end
	update_cursor_position
      end

      def message_more(m_buffer)
	m_height = term_height - text_height - 2

	m_height.times{print @m_buffer[i]}

#	@controller.more(m_height) do |i|
#	  m_height.times{print @m_buffer[i]}
#	end
	@message_h = m_height
	update_cursor_position
      end

      def message_clear
	return if @message_h == 0
	move_to_message_frame
	@message_h.times{ti_delete_line}
	@message_h = 0
      end


    end
  end
end

