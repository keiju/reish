#
#   reish/input-method/input-method.rb - input methods used irb
#                         oroginal version from irb.
#   	Copyright (C) 2014-2017 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
module Reish
  class InputMethod

    # Creates a new input method object
    def initialize(exenv, *opts)
      @exenv = exenv
      @completable = false
    end

    def completable?; @completable; end

    # The irb prompt associated with this input method
    attr_accessor :prompt

    # Reads the next line from this input method.
    #
    # See IO#gets for more information.
    def gets
      Reish.fail NotImplementedError, "gets"
    end
    public :gets

    # Whether this input method is still readable when there is no more data to
    # read.
    #
    # See IO#eof for more information.
    def readable_after_eof?
      false
    end

    def tty?
      false
    end 

    def real_io
      Reish.fail NotImplementedError, "gets"
    end

  end

  class StringInputMethod < InputMethod

    def initialize(exenv, string)
      super
      @lines = string.lines
      @lines = [""] if @lines.empty?
      if /\n/ !~ @lines.last[-1] 
	#	@lines.last.concat "\n"
      end
    end

    def gets
      @lines.shift
    end
  end

  class QueueInputMethod < InputMethod
    def initialize(exenv, que)
      super
      @queue = que
    end

    def gets
      @queue.shift
    end
  end
end

require "reish/input-method/stdio-im"
require "reish/input-method/file-im"
require "reish/input-method/readline-im"
require "reish/input-method/reidline-im"
