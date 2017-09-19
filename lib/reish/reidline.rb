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

      @completion_proc = nil
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

    def input_complete
      @history.push @editor.buffer if auto_history?
      @editor.set_buffer
    end

    def gets
      @editor = Editor.new
      @multi_line_mode = false
      @editor.set_cmpl_proc(&@cmpl_proc)
      begin
	line = @editor.gets
      rescue Interrupt
	input_complete
	raise
      rescue
	puts "reidline abort!!"
	input_complete
	raise
      end until @completion_proc.call(line)
      input_complete
      line
    end

    def set_completion_proc(&block)
      @completion_proc = block
    end

    def message(str)
      @editor.message(str)
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


    
