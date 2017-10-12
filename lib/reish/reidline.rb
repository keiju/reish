#
#   reidline.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "reish/reidline/editor"

module Reish
  class Reidline
    def initialize
#      @editor = Editor.new
#      @multi_line_mode = false

      @call_backs = {}

      @history = []

      @auto_history = false

      @multi_line_edit = false
      @continue = true

      @closed_proc = nil
      @prompt_proc = nil
    end

    attr_accessor :multi_line_mode
    alias multi_line_mode? multi_line_mode

    attr_reader :history

    attr_reader :multi_line_edit
    alias multi_line_edit? multi_line_edit

    attr_accessor :auto_history
    alias auto_history? auto_history

    attr_accessor :continue
    alias continue? continue

    def input_closed
      @history.push @editor.buffer if auto_history?
      @editor.set_buffer
    end

    def init_editor
      @editor = Editor.new
      @editor.history = @history
      @multi_line_mode = false
      @editor.set_closed_proc(&@closed_proc)
      @editor.set_cmpl_proc(&@cmpl_proc)
    end

    def get_lines(prompt = nil)
      init_editor unless @editor
      begin
	lines = @editor.get_lines(prompt)
      rescue Interrupt
	input_closed
	raise
      rescue
	puts "reidline abort!!"
	input_closed
	raise
      end #until @closed_proc.call(lines)
      input_closed
      @history << lines unless /^\s+$/ =~ lines
      lines
    end

    def set_closed_proc(&block)
      @closed_proc = block
    end

    def message(str, append: false)
      @editor.message(str, append: append)
    end

    def set_prompt(line_no, prompt)
      @editor.set_prompt(line_no, prompt)
    end

    # call_caks:
    #   enter_mutiline_edit
    #   
    def call_back(event, &plock)
      @call_backs[event] = block
    end

    def set_cmpl_proc(&block)
      @cmpl_proc = block
    end

  end
end


    
