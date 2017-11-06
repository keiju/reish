#
#   pager.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

module Reish
  class Reidline
    class Pager
      include Enumerable

      def initialize(view, ary = [])
	@view = view
	@buffer = ary
      end

      def empty?
	@buffer.empty?
      end

      def size
	@buffer.size
      end

      def push(str)
	@buffer.push str
      end

      def [](*args)
	@buffer[*args]
      end

      def each(&block)
	@buffer.each &block
      end

      def last
	@buffer.last
      end

      def inspect
	"#<Pager: @view=#{@view} @buffer=#{@buffer.inspect}>"
      end

    end
  end
end




