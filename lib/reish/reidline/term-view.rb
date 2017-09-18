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

	@ORG_H = nil
	
	@message_h = 0
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
	
	@ORG_H, dummy = ti_cursor_pos

	@cache = []
	@buffer.each do |line|
	  @cache.push slice_width(line)
	end

	line_last = @cache.last.last
	@cache.each do |lines|
	  lines.each do |line|
	    if line.equal?(line_last)
	      print line
	    else
	      puts line 
	    end
	  end
	end

	if @ORG_H + text_height > @term_height
	  @ORG_H = @term_height - text_height
	end

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

      def cursor_position(row, col)
	h, w = term_pos(row, col)
	ti_cursor_position(@ORG_H+h, w)
      end

      def cursor_move(t_row, t_col)
	c_row, c_col = term_pos(@controller.c_row, @controller.c_col)
	h = t_row - c_row
	w = t_col - c_col
	ti_move(h, w)
      end

      def insert_line
	if @ORG_H + text_height + @message_h < @term_height
	  ti_insert_line
	else
	  ti_scroll_up
	  ti_insert_line
	  @ORG_H -= 1
	end
      end
     
      def update_insert(row, col, len)
	ti_save_position do
	  t_row, t_col = term_pos(row, col)
	  cursor_move(t_row, t_col)
	
	  ti_ins_mode do
	    sub_row, sub_col = cache_col(row, col)
	    @cache[row][sub_row].insert(sub_col, @buffer[row][col, len])
	    print(@buffer[row][col, len])
	    until @cache[row][sub_row].bytesize <= @term_width
	      split = slice_width(@cache[row][sub_row])
	      @cache[row][sub_row] = split.shift
	      until split.size <= 2
		sub = split.shift
		@cache[row].insert(sub_row, sub)
		insert_line
		ti_line_beg; ti_down
		print(sub)
		sub_row += 1
	      end
	      sub = split.first
	      ti_down; ti_line_beg
	      print sub
	      sub_row += 1
	      @cache[row][sub_row] = "" if @cache[row][sub_row].nil?
	      @cache[row][sub_row].insert(0, sub)
	    end
	    if @cache[row][sub_row].bytesize == @term_width
	      @cache[row].push ""
	      insert_line
	      ti_line_beg
	    end
	  end
	end
      end

      def insert_string_sub(row, col, str)
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
	      insert_line
	      ti_line_beg; ti_down
	      print(sub)
	      sub_row += 1
	    end
	    sub = split.first
	    ti_down; ti_line_beg
	    print sub
	    sub_row += 1
	    @cache[row][sub_row] = "" if @cache[row][sub_row].nil?
	    @cache[row][sub_row].insert(0, sub)
	  end
	  if @cache[row][sub_row].bytesize == @term_width
	    @cache[row].push ""
	    insert_line
	    ti_line_beg
	  end
	end
      end

      def update_delete(row, col)
	ti_save_position do
	  t_row, t_col = term_pos(row, col)

	  cursor_move(t_row, t_col)

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
	ti_save_position do
	  t_row, t_col = term_pos(row, @buffer[row].size)
	  cursor_move(t_row, t_col)
	  insert_line
	  @cache.insert(row+1, [""])
	end
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
	ti_save_position do
	  t_row, t_col = term_pos(row, col)

	  cursor_move(t_row, t_col)
	
	  sub_row, sub_col = cache_col(row, col)
	  sub = @cache[row][sub_row].slice!(sub_col .. -1)
	  ti_clear_eol
	  if sub_row < @cache[row].size
	    sub.concat @cache[row].slice!(sub_row+1..-1).join
	  end
	  @cache.insert(row+1, [""])
	  #insert_line; 
	  ti_line_beg; 
	  ti_down
	  ti_clear_eol; ti_up
	  insert_string_sub(row+1, 0, sub)
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
    end
  end
end

