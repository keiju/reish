#
#   history-session.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

module Reish
  class Reidline
    class HistorySession
      def initialize(editor, history)
	@editor = editor
	@history = history
	@current = 0
	@buffers = []
      end

      def reset
	@current = 0
	@buffers.clear
      end

      def prev
	@buffers[@current] = @editor.buffer

	@current += 1
	if @history.size < @current
	  @current -= 1
	end
	unless lines = @buffers[@current]
	  lines = @history[-@current]
	end
	@editor.cursor_beginning_of_buffer
	@editor.set_buffer lines
	@editor.closed?
      end

      def next
	@buffers[@current] = @editor.buffer

	@current -= 1
	if @current < 0
	  @current = 0
	end
	
	unless lines = @buffers[@current]
	  lines = @history[-@current]
	end
	@editor.cursor_beginning_of_buffer
	@editor.set_buffer(lines)
	@editor.closed?
      end
    end
  end
end
