#
#   composite-messenger.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "reidline/messenger"

module Rei
  class Reidline
    class CompositeMessenger<Messenger
      
      def initialize(ary = [], view: nil, title: title)
	@view = view
	@title = title
	@buffers = ary
      end

      def attach_view(view)
	@view = view

	@buffers.each do |buf|
	  buf.attach_view(view)
	end
      end

      def size
	@buffers.inject(0){|s, b| s += b.height}
      end

      def push(buffer)
	case buffer
	when String
	  buffer = Messenger.new(buffer)
	end
	buffer.attach_view @view if @view
	@buffers.push buffer
      end

      undef []

      def last
	@buffers.last.last
      end

      def line(idx)
	@buffers.each do |buffer|
	  if idx < buffer.height
	    if buffer.title
	      if idx == 0
		return buffer.title
	      else
		return buffer.line(idx-1)
	      end
	    else
	      return buffer.line(idx)
	    end
	  end
	  idx -= buffer.height
	end
      end
      
      def inspect
	"#<CompMessenger: @view=#{@view} @buffers=#{@buffes.inspect}>"
      end

    end
  end
end
    

      
      
