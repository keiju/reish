#
#   reidline.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "reish/reidline/editor"

module Reish
  class Reidline
    def initialize
      @editor = Editor.new

      @history = []

      @auto_history = false
      @continue = false
    end

    attr_reader :history

    attr_accessor :auto_history
    alias auto_history? auto_history

    attr_accessor :continue
    alias continue? continue

    def gets
      unless continue?
	@history.push @editor.buffer if auto_history?
	@editor.set_buffer
      end

      @editor.gets
    end

    end
end


    
