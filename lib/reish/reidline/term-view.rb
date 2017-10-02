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
	@cache_prompts = []

	@t_row = nil
	@t_col = nil

#	@ORG_H = nil
	
	@message_h = 0
      end

      def reset_cursor_position
	@t_row = text_height - 1
	@t_col = @cache.last.last.bytesize + (@cache_prompts[@cache.size-1]&.bytesize || 0)
	cursor_reposition
      end

      def text_height
	@cache.inject(0){|r, lines| r += lines.size}
      end

      def offset(row, sub_row = 0)
	if sub_row == 0
	  offset = @cache_prompts[row]&.bytesize || 0
	else
	  0
	end
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

      def clear_display
	ti_clear
#	@ORG_H = 0
	redisplay(cache_update: true)
      end

      def redisplay(from: 0, cache_update: false)
	if cache_update
	  @cache = []
	  @cache_prompts = []
	  @buffer.each_with_prompt do |line, prompt|
	    @cache_prompts.push prompt
	    @cache.push slice_width(line, offset: prompt.bytesize)
	  end
	end

	i = 0
	line_last = @cache.last.last
	@cache.zip(@cache_prompts) do |lines, prompt|
	  top = lines.first
	  lines.each do |line|
	    i += 1
#ttyput @cache
#ttyput prompt
#ttyput @cache_prompts
	    next if from >= i

	    print prompt if top.equal?(line)
	    print_eol line
	    if !line.equal?(line_last)
	      print "\n"
	    end
	  end
	end
	reset_cursor_position
      end

      def slice_width(str, width = @term_width, offset: 0)
	str = str.dup
	split = []
	until str.size == 0
	  s0 = str.slice!(0, width - offset)
	  until s0.bytesize <= width - offset
	    str.prepend s0.slice!(-1)
	  end
	  split.push s0
	end
	split.push "" if split.empty? #|| split.last.size == width
	split
      end

      def cache_col(row, col)
	lines = @cache[row]
	i = 0
	until col <= lines[i].size
	  col -= lines[i].size
	  i += 1
	end
	if col == lines[i].size && lines[i+1]
	  col -= lines[i].size
	  i += 1
	end
	return i, col
      end

      def cache_col2t_row(row, sub_row)
	i = 0
	line_last = @cache[row][sub_row]
	@cache.each do |lines|
	  lines.each do |line|
	    return i if line.equal?(line_last)
	    i += 1
	  end
	end
	return i
      end

      def term_pos(row, col)
#	if @buffer[row].size < col
#	  col = @buffer[row].size
#	end
	
#ttyput "TERM_POS"
#ttyput row, col
#ttyput @cache

	len = @cache[row].inject(0){|s, e| s + e.size}
#ttyput len
	if len < col
	  col = len
	end

	h = 0
	for i in 0..(row-1)
	  h += @cache[i].size
	end

	sub_row, sub_col = cache_col(row, col)
	if sub_col == 0
	  w = offset(row, sub_row)
	else
	  w = offset(row, sub_row)+@cache[row][sub_row][0..sub_col-1].bytesize
	end

#ttyput h+sub_row, w
	return h+sub_row, w
      end

#      def term_rpos(row, col)
#	h, w = term_pos(row, col)
#	return h - @controller.c_row, w - @controller.c_col
#      end

      def cursor_reposition
#ttyput "CURSOR_REPOSITON"
	t_row, t_col = term_pos(@controller.c_row, @controller.c_col)
	h = t_row - @t_row
	w = t_col - @t_col
	@t_row = t_row
	@t_col = t_col
#ttyput h, w
	ti_move(h, w)
      end

      def cursor_move(t_row, t_col)
#	c_row, c_col = term_pos(@controller.c_row, @controller.c_col)
	dh = t_row - @t_row
	dw = t_col - @t_col
	@t_row = t_row
	@t_col = t_col
	ti_move(dh, dw)
      end

      def cursor_save_position(&block)
	b_row = @t_row
	b_col = @t_col
	begin
	  ti_save_position &block
	ensure
	  @t_row = b_row
	  @t_col = b_col
	end
      end

      def cursor_up(c=1)
	@t_row -= c
	ti_up(c)
      end

      def cursor_down(c=1)
	@t_row += c
	ti_down(c)
      end

      def cursor_right(c=1)
	@t_col += c
	ti_right(c)
      end

      def cursor_left(c=1)
	@t_col -= c
	ti_left(c)
      end

      def cursor_bol
	@t_col = 0
	ti_line_beg
      end
      
      def cursor_col(col)
	@t_col = col
	ti_hpos(col)
      end

      def update_insert(row, col, len)
#	ti_save_position do
	cursor_save_position do
	  !insert_string_sub(row, col, @buffer[row][col, len])
	end
      end

      def insert_string_sub(row, col, str, redisplay: false)
	insert_line_row = nil

	t_row, t_col = term_pos(row, col)
	cursor_move(t_row, t_col)

	ti_ins_mode do
	  sub_row, sub_col = cache_col(row, col)
	  @cache[row][sub_row].insert(sub_col, str)
	  
	  if redisplay
	    insert_line_row = [row, sub_row]
	  else
	    print str
	  end
	  until @cache[row][sub_row].bytesize <= @term_width - offset(row, sub_row)
	    split = slice_width(@cache[row][sub_row], offset: offset(row, sub_row))
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
	      cursor_down; corsor_bol
	      print sub
	    end
	    sub_row += 1
	    @cache[row][sub_row] = "" if @cache[row][sub_row].nil?
	    @cache[row][sub_row].insert(0, sub)
	  end
	  if @cache[row][sub_row].bytesize == @term_width - offset(row, sub_row)
	    @cache[row].push ""
	    unless insert_line_row
#	      insert_line
#	      ti_line_beg
	    else
	      insert_line_row = row, sub_row
	    end
	  end
	  redisplay(from: cache_col2t_row(*insert_line_row)) if insert_line_row
	end
	insert_line_row
      end

      def update_delete(row, col)
	t_row, t_col = term_pos(row, col)

	cursor_move(t_row, t_col)
	sub_row, sub_col = cache_col(row, col)
	@cache[row][sub_row].slice!(col, 1)
	ti_del
	

	until @cache[row][sub_row+1].nil? 
	  if @cache[row][sub_row].bytesize + @cache[row][sub_row+1][0].bytesize <= @term_width - offset(row, sub_row)
	    cursor_col(@cache[row][sub_row].bytesize+offset(row, sub_row))
	    cursor_save_positon do
	      ti_ins_mode do
		print @cache[row][sub_row+1][0]
		@cache[row][sub_row].concat @cache[row][sub_row+1].slice!(0,1)
		cursor_bol; cursor_down
		ti_del
		if @cache[row][sub_row+1].size == 0
		  @cache[row].slice!(sub_row+1)
		  ti_delete_line
		end
		sub_row += 1
	      end
	    end
	  end
	end
	if @cache[row].empty? && @cache.size > 0
	  @cache.slice!(row)
	end
      end

      def update_insert_line(row)
	t_row, t_col = term_pos(row, @buffer[row].size)
	cursor_move(t_row, t_col)
	@cache.insert(row+1, [""])
	print "\n"
	ti_clear_eol
	redisplay(from: row+1)
      end

      def update_delete_line(row)
	cursor_save_position do
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
	if @cache.size - 1 <= row + 1
	  print_eol "\n"
	  @t_row += 1
	  @t_col = 0
	end
	insert_string_sub(row+1, 0, sub, redisplay: true)
      end

      def update_join_line(row, col, len)
	update_delete_line(row+1)
	cursor_save_position do
	  update_insert(row, col, len)
	end
      end

      def update_delete_eol(row, col)
	t_row, t_col = term_pos(row, col)

	cursor_move(t_row, t_col)
	
	sub_row, sub_col = cache_col(row, col)
	sub = @cache[row][sub_row].slice!(sub_col .. -1)
	ti_clear_eol
	if sub_row < @cache[row].size
	  @cache[row].slice!(sub_row+1..-1)
	end
      end

      def update_prompt(row)
	return if @buffer.prompts[row] == @cache_prompts[row]

	cursor_save_position do
	  t_row, t_col = term_pos(row, 0)
	  cursor_move(t_row, t_col)

	  prompt = @buffer.prompts[row]
	  if slice_width(@cache[row].first, offset: prompt.bytesize).size > 1
	    @cashe_prompts[row] = prompt
	    redisplay(row, cache_update: true)
	  else
	    diff = prompt.bytesize - (@cache_prompts[row]&.bytesize || 0)
	    @cache_prompts[row] = prompt
	    if diff > 0
	      print " "*diff
	    else
	      diff.times{ti_del}
	    end
	    ti_line_beg
	    print prompt
	    @t_col += prompt.bytesize
	  end
	end
      end

      def update(id, *args)
	updater = "update_#{id.id2name}"
	if respond_to?(updater)
	  send updater, *args
	else
	  raise ArgumentError, "Unregistered id: #{id}"
	end
      end

      def message(str)
	message_clear if @message_h > 0
	message_cursor_save do
	  m_buffer = []

	  lines = str.lstrip.split(/\n/)
	
	  lines.each do |line|
	    ll = slice_width(line)
	    ll.each do |l|
	      m_buffer.push l
	    end
	  end
#ttyput m_buffer
	  if m_buffer.size + text_height < @term_height
	    m_buffer.each do |l|
	      if l == m_buffer.last
		print l
	      else
		puts l
	      end
	    end
	    @message_h = m_buffer.size
	  else
	    message_more(m_buffer)
	  end
	end
      end

      def message_more(m_buffer)
	m_height = @term_height - text_height - 2

	m_height.times{print @m_buffer[i]}

#	@controller.more(m_height) do |i|
#	  m_height.times{print @m_buffer[i]}
#	end
	@message_h = m_height
	reset_cursor_position
      end

      def message_clear
	return if @message_h == 0

	message_cursor_save do
	  @message_h.times{ti_delete_line}
	  @message_h = 1
	end
	@message_h = 0
      end

      def message_cursor_save(&block)
	b_row = @t_row
	b_col = @t_col

	t_row, t_col = term_pos(text_height - 1, @cache[text_height - 1].size - 1)
	cursor_move(t_row, t_col)
	print "\n"
	
	block.call
	
	ti_up(text_height + @message_h - b_row - 1)
	ti_hpos(b_col)
	@t_row = b_row
	@t_col = b_col
#ttyput "MCS:", text_height, @message_h, b_row, b_col
#	reset_cursor_position
      end

      def print_eol(str)
	print str
	ti_clear_eol
      end
      
    end
  end
end

