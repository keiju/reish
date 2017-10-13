#
#   reish/input-method/file-im.rb - input methods used irb
#                         oroginal version from irb.
#   	Copyright (C) 2014-2017 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
require 'reish/src_encoding'
require 'reish/magic-file'

module Reish
  # Use a File for IO with irb, see InputMethod
  class FileInputMethod < InputMethod
    # Creates a new input method object
    def initialize(file)
      super
      @io = Reish::MagicFile.open(file)
    end
    # The file name of this input method, usually given during initialization.
    attr_reader :file_name

    # Whether the end of this input method has been reached, returns +true+ if
    # there is no more data to read.
    #
    # See IO#eof? for more information.
    def eof?
      @io.eof?
    end

    # Reads the next line from this input method.
    #
    # See IO#gets for more information.
    def gets
      print @prompt
      l = @io.gets
      l
    end

    # The external encoding for standard input.
    def encoding
      @io.external_encoding
    end

    def real_io
      @io
    end
  end
end
