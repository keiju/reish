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

	@TERM_H, @TERM_W = ti_winsize

	@buffer = nil
	@cache = nil
	@cache_prompts = []
	@cache_indents = []

	@t_row = 0
	@t_col = 0

#	@ORG_H = nil

	@OFF_H = 0
	@WIN_H = nil
	
	@m_buffer = nil
      end

      attr_reader :TERM_H, :TERM_W
      attr_reader :WIN_H, :OFF_H

      def indent(row, sub_row = 0)
	if sub_row == 0
	  "  " * (@cache_indents[row] || 0)
	else
	  ""
	end
      end

      def offset(row, sub_row = 0)
	if sub_row == 0
	  offset = (@cache_prompts[row]&.bytesize || 0) + indent(row).size
	else
	  0
	end
      end

      def last_offset
	offset(@cache_prompts.size - 1)
      end

#       def reset_cursor_position
# 	if @WIN_H
# 	  @t_row = @WIN_H + @OFF_H - 1
# 	else
# 	  @t_row = text_height - 1
# 	end
# 	@t_col = @cache.last.last.bytesize + last_offset
# 	cursor_reposition
#       end

      def text_height
	@cache.inject(0){|r, lines| r += lines.size}
      end

      def win_height
	@WIN_H || [text_height - @OFF_H, @TERM_H].min
      end

      def change_buffer
	old_height = nil
	if @buffer 
	  old_height = text_height
	  @buffer.delete_observer(self)
	end

	@buffer = @controller.buffer
	@buffer.add_observer(self)
	
#	@ORG_H, dummy = ti_cursor_pos

	cursor_bol
	redisplay cache_update: true, height: old_height
      end

      def clear_display
	ti_clear
#	@ORG_H = 0
	@WIN_H = nil

	th = text_height
	if @TERM_H >= th
	  @WIN_H = nil
	  @OFF_H = 0
	else
	  @WIN_H = @TERM_H
	  @OFF_H = @t_row - (@WIN_H/2.0).ceil
	  if @OFF_H < 0
	    @OFF_H = 0
	  elsif @OFF_H > @t_row 
	    @OFF_H = 0
	  elsif @OFF_H > th - @t_row
	    @OFF_H = th - @WIN_H
	  end
	end

	redisplay(cache_update: true)
      end

      def clear_prompt_line
	ti_line_beg
	ti_clear_eol
      end

      def redisplay(from: 0, cache_update: false, height: nil, t_row: @t_row,
		    adjust: true)
	if cache_update
	  @cache = []
	  @cache_prompts = []
	  @cache_indents = []
	  @buffer.each_with_prompt do |line, prompt, indent|
	    @cache_prompts.push prompt
	    @cache_indents.push indent
	    @cache.push slice_width(line, offset: last_offset)
	  end
	end
	th = text_height
	if adjust
	  if th <= @TERM_H
	    @OFF_H  = 0
	    @WIN_H = nil
	  else
	    if th - @OFF_H <= @TERM_H
	      @WIN_H = nil
#	      @OFF_H = th - @TERM_H
	    else
#	    @OFF_H = th - @TERM_H + 1
	      @WIN_H = @TERM_H 
	    end
	  end
	end

	# カーソルがウィンドウに入るように調整
	if (@OFF_H || 0) > t_row
	  @OFF_H = t_row
	elsif @WIN_H && @WIN_H + (@OFF_H || 0) <= t_row
	  @OFF_H = t_row - @TERM_H + 1
	end

	i = 0
	ti_line_beg
	line_last = @cache.last.last
	last_line = nil
	last_prompt = nil
	@cache.each_with_index do |lines, row|
#	@cache.zip(@cache_prompts) do |lines, prompt|
	  top = lines.first
	  lines.each do |line|
	    i += 1
	    next if from >= i
	    if @WIN_H && @OFF_H+@WIN_H < i
	      break
	    end

	    if top.equal?(line) && @buffer.prompts[row]
	      prompt = @cache_prompts[row] = @buffer.prompts[row]
	      @cache_indents[row] = @buffer.indents[row]
	      last_prompt = prompt + indent(row)
	      print last_prompt
	    end
	    print_eol line
	    if !line.equal?(line_last) && (!@WIN_H || @OFF_H+@WIN_H > i)
	     print "\n"
	    end
	    last_line = line
	  end
	end
	if height && i < height
	  ti_down
	  (height-i).times{ti_delete_line}
	  ti_up
	end

	if @WIN_H
	  @t_row = @WIN_H + @OFF_H - 1
	  @t_col = last_line.bytesize + last_prompt.bytesize
	else
	  @t_row = text_height - 1
	  @t_col = @cache.last.last.bytesize + last_offset
	end
	cursor_reposition
      end

      def reprompt(from)
	i = 0
	line_last = @cache.last.last
	@cache.each_with_index do |lines, row|
	  top = lines.first
	  lines.each do |line|
	    i += 1
	    next if from > i
	    if top.equal?(line)
	      prompt =  @buffer.prompts[row]
	      indent = @buffer.indents[row]
	      if slice_width(@cache[row].first, offset: prompt.bytesize+indent*2).size > 1
		@cache_prompts[row] = prompt
		@cache_indents[row] = indent
		return redisplay(row, cache_update: true)
	      else
		diff = prompt.bytesize + indent*2 - offset(row)
		@cache_prompts[row] = prompt
		@cache_indents[row] = indent
		if diff > 0
		  print " "*diff
		else
		  diff.times{ti_del}
		end
		ti_line_beg
		print prompt+indent(row)
	      end
	    end
	    cursor_bol
	    cursor_down
	  end
	end
      end

      def slice_width(str, width = @TERM_W, offset: 0)
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

      def term_pos(row, col, offset: true)
	len = @cache[row].inject(0){|s, e| s + e.size}
	if len < col
	  col = len
	end

	h = 0
	for i in 0..(row-1)
	  h += @cache[i].size
	end

	sub_row, sub_col = cache_col(row, col)
	if offset
	  of =  offset(row, sub_row) 
	else
	  of = 0
	end
	if sub_col == 0
	  w = of
	else
	  w = of+@cache[row][sub_row][0..sub_col-1].bytesize
	end

	return h+sub_row, w
      end

#      def term_rpos(row, col)
#	h, w = term_pos(row, col)
#	return h - @controller.c_row, w - @controller.c_col
#      end

      def cursor_reposition
	b_row = @t_row
	c_col = @t_col
	t_row, t_col = term_pos(@controller.c_row, @controller.c_col)
	dh = t_row - @t_row
 	dw = t_col - @t_col
 	@t_row = t_row
 	@t_col = t_col
	if @t_row < @OFF_H
	  @OFF_H = @t_row
	  ti_up(b_row)
	  redisplay(from: @OFF_H, cache_update: false, adjust: false)
	elsif  @WIN_H && @WIN_H + @OFF_H <= @t_row || @TERM_H + @OFF_H <= @t_row
	  @WIN_H = @TERM_H unless @WIN_H
	  oo = @OFF_H
	  @OFF_H = @t_row - @WIN_H + 1
	  ti_up(b_row)
	  redisplay(from: @OFF_H, cache_update: false, adjust: false)
	else
	  ti_move(dh, dw)
	end
      end

      def cursor_move(t_row, t_col)
#	c_row, c_col = term_pos(@controller.c_row, @controller.c_col)
	dh = t_row - @t_row
	dw = t_col - @t_col
	@t_row = t_row
	@t_col = t_col
	if @t_row < @OFF_H
	  d = @OFF_H - @t_row
	  @OFF_H = @t_row
	  redisplay(from: @t_row, cache_update: false)
	  ti_move(0, dw)
	else
	  ti_move(dh, dw)
	end
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
	if @t_row >= @OFF_H
	  ti_up(c)
	else
	  @OFF_H -= 1
	  redisplay(from: @OFF_H, cache_update:false)
	end
      end

      def cursor_down(c=1)
	@t_row += c
	if @WIN_H && @OFF_H + @WIN_H >= @t_row
	  @OFF_H += 1
	  redisplay(from: @OFF_H, cache_update:false)
	else
	  ti_down(c)
	end
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

#      def cursor_eol
#	
#	ti_line_beg
#      end
      
      def cursor_col(col)
	@t_col = col
	ti_hpos(col)
      end

      def cursor_bob
	cursor_bol
	cursor_up(@t_row)
      end

      def cursor_eob
	cursor_bol
	cursor_down(text_height - @t_row - 1)
	cursor_eol
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
	  until @cache[row][sub_row].bytesize <= @TERM_W - offset(row, sub_row)
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
	  if @cache[row][sub_row].bytesize == @TERM_W - offset(row, sub_row)
	    @cache[row].push ""
	    unless insert_line_row
#	      insert_line
#	      ti_line_beg
	    else
	      insert_line_row = row, sub_row
	    end
	  end
	end
	if insert_line_row
	  ti_line_beg
	  redisplay(from: cache_col2t_row(*insert_line_row)) 
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
	  if @cache[row][sub_row].bytesize + @cache[row][sub_row+1][0].bytesize <= @TERM_W - offset(row, sub_row)
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
	t_row, t_col = term_pos(row, @buffer[row].size-1)
	cursor_move(t_row, t_col)
	@cache.insert(row+1, [""])
	print "\n"
	ti_clear_eol
	redisplay(from: row+1, t_row: @t_row + 1)
      end

      def update_delete_line(row)
	cursor_save_position do
	  t_row, t_col = term_pos(row, 0)
	  cursor_move(t_row, t_col)
	  n = @cache[t_row].size
	  @cache.slice!(t_row)
	  @cache_prompts.slice!(t_row)
	  @cache_indents.slice!(t_row)
	  n.times{ti_delete_line}
	  if @WIN_H
	    redisplay(from: t_row)
	  else
	    reprompt(t_row+1)
	  end
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

      def update_prompt(row, force: false)
	if !force && 
	    @buffer.prompts[row] == @cache_prompts[row] && 
	    @buffer.indents[row] == @cache_indents[row]
	  return 
	end
	unless @cache[row]
	  @cache_prompts[row] = @buffer.prompts[row]
	  @cache_indents[row] = @buffer.indents[row]
	  return
	end

	cursor_save_position do
	  t_row, t_col = term_pos(row, 0)
	  return if @OFF_H > t_row || @WIN_H && @WIN_H < t_row
	  cursor_move(t_row, t_col)

	  prompt = @buffer.prompts[row]
	  indent = @buffer.indents[row]
	  if slice_width(@cache[row].first, offset: prompt.bytesize+indent*2).size > 1
	    @cache_prompts[row] = prompt
	    @cache_indents[row] = indent
	    redisplay(from: row, cache_update: true)
	  else
	    diff = prompt.bytesize + indent*2 - offset(row)
	    @cache_prompts[row] = prompt
	    @cache_indents[row] = indent
	    if diff > 0
	      ti_ins_mode do
		print " "*diff
	      end
	    else
	      ti_line_beg
	      (-diff).times{ti_del}
	    end
	    ti_line_beg
	    print prompt+indent(row)
	    @t_col += prompt.bytesize + @cache_indents[row]*2
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

      def message(str, append: false, buffer_class: nil)
	if !append && @m_buffer
	  message_clear
	end

	if append
	  m_buffer = @m_buffer.dup
	elsif buffer_class
	  m_buffer = buffer_class.new(self)
	else
	  m_buffer = []
	end

	case str
	when String
	  lines = str.lstrip.split(/\n/)
	when Array
	  lines = str
	end

	lines.each do |line|
	  ll = slice_width(line)
	  ll.each do |l|
	    m_buffer.push l
	  end
	end

	th = text_height
	message_h = @TERM_H - th
	mh = message_h - 1
	if text_height > @TERM_H + @OFF_H ||
	    text_height > @TERM_H.div(2) + @OFF_H
	  if @WIN_H && @TERM_H - @WIN_H >= m_buffer.size
	    message_cat(m_buffer)
	  else
	    if @TERM_H.div(2) > m_buffer.size
	      if th > @TERM_H - m_buffer.size
		@WIN_H = @TERM_H - m_buffer.size
		@OFF_H = (th - @WIN_H).div(2)
	      else
		@OFF_H = 0
		@WIN_H = th
	      end
	      ti_clear
	      redisplay(from: @OFF_H, adjust: false)
		
	      message_cat(m_buffer)
	    else
	      @WIN_H = (@TERM_H / 2.0).ceil
	      @OFF_H = @t_row - (@WIN_H/2.0).ceil
	      if @OFF_H < 0
		@OFF_H = 0
	      elsif @OFF_H > @t_row 
		@OFF_H = 0
	      elsif @OFF_H > th - @t_row
		@OFF_H = th - @WIN_H
	      end

	      ti_clear
	      redisplay(from: 0, adjust: false)
	      message_more(m_buffer)
	    end
	  end
	elsif text_height + m_buffer.size < @TERM_H
	  message_cat(m_buffer)
	else
	  message_more(m_buffer)
	end
      end

      def message_cat(m_buffer)
	unless m_buffer.kind_of?(Array)
	  @m_buffer = m_buffer
	  return @m_buffer.cat
	end

	message_cursor_save do
	  @m_buffer = m_buffer
	  @m_buffer.each do |l|
	    if l == @m_buffer.last
	      print l
	    else
	      puts l
	    end
	  end
	end
      end
      
      def message_more(m_buffer)
	unless m_buffer.kind_of?(Array)
	  @m_buffer = m_buffer
	  return @m_buffer.more
	end

	if @WIN_H
	  message_h = @TERM_H - @WIN_H
	else
	  message_h = @TERM_H - text_height
	end
	mh = message_h - 1

	message_cursor_save do
	  offset = 0
	  loop do
	    mh.times do |i| 
	      if m_buffer.size == offset+i
		@m_buffer = m_buffer[offset..-1]
		(mh - i).times do
		  ti_clear_eol
		  print_eol "\n"
		  @m_buffer.push ""
		end
		ti_clear_eol
		@m_buffer.push ""
		return
	      end
	      puts_eol m_buffer[offset+i]
	    end
	    offset += mh

	    print_width_winsz "CR: return, TAB: next-page, BS: back-page, or other character to pass itsself: "

	    ch = nil
	    STDIN.noecho do
	      STDIN.raw do
		ch = STDIN.getc
	      end
	    end

	    case ch
	    when "\C-m"
	      @m_buffer = m_buffer[offset-mh, mh]
	      @m_buffer.push ""
	      ti_delete_line
	      break
	    when "\t"
	      ti_up(mh)
	      ti_line_beg
	      next
	    when "\u007F"
	      offset -= mh*2
	      offset = 0 if offset < 0

	      ti_up(mh)
	      ti_line_beg
	      next
	    else
	      @m_buffer = m_buffer[offset-mh, mh]
	      @m_buffer.push ""
	      STDIN.ungetc(ch)
	      ti_delete_line
	      break
	    end
	  end
	end
      end

      def message_clear
	return unless @m_buffer

	message_cursor_save do
	  @m_buffer.each{ti_delete_line}
	  @m_buffer = [""]
	end
	@m_buffer = nil
      end

      def message_cursor_save(&block)
	begin
	  b_row = @t_row
	  b_col = @t_col

	  if @WIN_H
	    t_row, t_col = term_pos(@WIN_H + @OFF_H - 1, 0)
	  else
	    t_row, t_col = term_pos(text_height - 1, @cache[text_height - 1].size - 1)
	  end
	  cursor_move(t_row, t_col)
#	if append
#	  ti_down(@m_buffer.size)
#	end
	  print "\n"
#	  ti_save_position do
	    block.call
#	  end
	
	ensure
	  if @WIN_H
	    ti_up(@WIN_H + @OFF_H + @m_buffer.size - b_row - 1)
	  else
	    ti_up(text_height + @m_buffer.size - b_row - 1)
	  end
	  ti_hpos(b_col)
	  @t_row = b_row
	  @t_col = b_col
#	reset_cursor_position
	end
      end

      def print_eol(str)
	print str
	ti_clear_eol
      end

      def puts_eol(str = nil)
	print str if str
	ti_clear_eol
	print "\n"
      end

      def print_width_winsz(str)
	print str[0, @TERM_W]
      end
    end
  end
end

