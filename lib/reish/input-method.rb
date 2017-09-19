#
#   irb/input-method.rb - input methods used irb
#                         oroginal version is irb.
#   	Copyright (C) 2014-2017 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
require "forwardable"

require 'reish/src_encoding'
require 'reish/magic-file'

require "reish/reidline"


module Reish
  STDIN_FILE_NAME = "(line)" # :nodoc:
  class InputMethod

    # Creates a new input method object
    def initialize(file = STDIN_FILE_NAME)
      @file_name = file
      @completable = false
    end
    # The file name of this input method, usually given during initialization.
    attr_reader :file_name
    
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

  class StdioInputMethod < InputMethod
    # Creates a new input method object
    def initialize
      super
      @line_no = 0
      @line = []
      @stdin = IO.open(STDIN.to_i, :external_encoding => Reish.conf[:LOCALE].encoding, :internal_encoding => "-")
      @stdout = IO.open(STDOUT.to_i, 'w', :external_encoding => Reish.conf[:LOCALE].encoding, :internal_encoding => "-")
    end

    # Reads the next line from this input method.
    #
    # See IO#gets for more information.
    def gets
      print @prompt
      line = @stdin.gets
      @line[@line_no += 1] = line
    end

    # Whether the end of this input method has been reached, returns +true+ if
    # there is no more data to read.
    #
    # See IO#eof? for more information.
    def eof?
      @stdin.eof?
    end

    # Whether this input method is still readable when there is no more data to
    # read.
    #
    # See IO#eof for more information.
    def readable_after_eof?
      true
    end

    # Returns the current line number for #io.
    #
    # #line counts the number of times #gets is called.
    #
    # See IO#lineno for more information.
    def line(line_no)
      @line[line_no]
    end

    # The external encoding for standard input.
    def encoding
      @stdin.external_encoding
    end

    def tty?
      @stdin.tty?
    end 

    def real_io
      STDIN
    end

  end

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

  begin
    require "readline"
    class ReadlineInputMethod < InputMethod
      include Readline
      # Creates a new input method object using Readline
      def initialize
        super

        @line_no = 0
        @line = []
        @eof = false

	@completable = true

        @stdin = IO.open(STDIN.to_i, :external_encoding => Reish.conf[:LOCALE].encoding, :internal_encoding => "-")
        @stdout = IO.open(STDOUT.to_i, 'w', :external_encoding => Reish.conf[:LOCALE].encoding, :internal_encoding => "-")

	@completor = nil
        Readline.completion_proc = nil
      end

      attr_accessor :completor

      # Reads the next line from this input method.
      #
      # See IO#gets for more information.
      def gets
        Readline.input = @stdin
        Readline.output = @stdout

	Readline.completion_proc = @completor.completion_proc if @completor

        if l = readline(@prompt, false)
          HISTORY.push(l) if !l.empty?
          @line[@line_no += 1] = l + "\n"
        else
          @eof = true
          l
        end
      end

      # Whether the end of this input method has been reached, returns +true+
      # if there is no more data to read.
      #
      # See IO#eof? for more information.
      def eof?
        @eof
      end

      # Whether this input method is still readable when there is no more data to
      # read.
      #
      # See IO#eof for more information.
      def readable_after_eof?
        true
      end

      # Returns the current line number for #io.
      #
      # #line counts the number of times #gets is called.
      #
      # See IO#lineno for more information.
      def line(line_no)
        @line[line_no]
      end

      # The external encoding for standard input.
      def encoding
        @stdin.external_encoding
      end

      def tty?
	@stdin.tty?
      end 

      def real_io
	@stdin
      end
    end
  rescue LoadError
  end

  class StringInputMethod < InputMethod

    def initialize(string)
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

  class ReidlineInputMethod < InputMethod
    extend Forwardable

    # Creates a new input method object using Readline
    def initialize
      @reidline = Reidline.new
      @reidline.multi_line_mode = true

      @line_no = 0
      @line = []
      @eof = false

      #	@completable = true

      #        @stdin = IO.open(STDIN.to_i, :external_encoding => Reish.conf[:LOCALE].encoding, :internal_encoding => "-")
      #        @stdout = IO.open(STDOUT.to_i, 'w', :external_encoding => Reish.conf[:LOCALE].encoding, :internal_encoding => "-")

      #	@completor = nil
      #        Readline.completion_proc = nil

      @lex = Lex.new
      @parser = Parser.new(@lex)
      @parser.cmpl_mode = true

      @reidline.set_completion_proc do |line|
	line.chomp!
	im = StringInputMethod.new(line)

	@lex.initialize_input
	@lex.set_input(im) do
	  if l = im.gets
#	    print l  if Reish::debug_cmpl?
	  else
#	    print "\n" if Reish::debug_cmpl?
	  end
	  l
	end

	ret = nil
	begin 
	  input_unit = [@parser.yyparse(@lex, :racc_token_cmpl)]
#	  puts "PARSE COMPLETED"  if Reish::debug_reid?
	  
	  ret = true
	rescue ParserComplSupp
	  if Reish::debug_cmpl?
	    puts "PARSE IMCOMLETED" 
	    require "pp"
	    puts "TEST_CMPL:"
	    pp @parser.cmpl_mode
	  end
	  ret = false
	end
	ret
      end
    end

    #      attr_accessor :completor

    # Reads the next line from this input method.
    #
    # See IO#gets for more information.
    def gets
      #        Readline.input = @stdin
      #        Readline.output = @stdout

      #	Readline.completion_proc = @completor.completion_proc if @completor

      if l = @reidline.gets
	#          HISTORY.push(l) if !l.empty?
	@line[@line_no += 1] = l + "\n"
      else
	@eof = true
	l
      end
    end

    # Whether the end of this input method has been reached, returns +true+
    # if there is no more data to read.
    #
    # See IO#eof? for more information.
    def eof?
      @eof
    end

    # Whether this input method is still readable when there is no more data to
    # read.
    #
    # See IO#eof for more information.
    def readable_after_eof?
      true
    end

    # Returns the current line number for #io.
    #
    # #line counts the number of times #gets is called.
    #
    # See IO#lineno for more information.
    def line(line_no)
      @line[line_no]
    end

    # The external encoding for standard input.
    def encoding
      @stdin.external_encoding
    end

    def tty?
      STDIN.tty?
    end 

    def real_io
      STDIN
    end

  end

end
