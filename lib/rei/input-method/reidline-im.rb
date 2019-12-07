#
#   rei/input-method/input-method.rb - input methods used rei-systems
#   	Copyright (C) 2014-2017 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
require "forwardable"

require 'rei/src_encoding'
require 'rei/magic-file'

require "reidline"

module REI
  class ReidlineInputMethod < InputMethod
    extend Forwardable

    # Creates a new input method object using Readline
    def initialize(exenv)
      super

      @reidline = Reidline.new
      @reidline.multi_line_mode = true
      @reidline.auto_indent = @exenv.auto_indent

      @line_no = 0
      @line = []
      @eof = false

      @completable = true

      @completor = nil
      @promptor = nil

      @nesting = nil

      #        @stdin = IO.open(STDIN.to_i, :external_encoding => Reish.conf[:LOCALE].encoding, :internal_encoding => "-")
      #        @stdout = IO.open(STDOUT.to_i, 'w', :external_encoding => Reish.conf[:LOCALE].encoding, :internal_encoding => "-")

      #	@completor = nil
      #        Readline.completion_proc = nil

      @lex = create_lex
      @in_queue = Queue.new
      @im = QueueInputMethod.new(nil, @in_queue)

      @lex.set_prompt do |ltype, indent, continue, line_no|
	idx = line_no - @line_no
	@nesting[idx] = indent.dup
	set_indent(idx)
	if @promptor
	  @reidline.set_prompt(idx, @promptor.call(line_no, indent, ltype, continue), indent.size)
	end
      end

      @lex.set_input(@im){@im.gets}
      @reidline.set_closed_proc &method(:closed?)
    end

    attr_accessor :completor
    attr_accessor :promptor

    def create_lex
      REI::Fail NotImplementedError, "create_lex"
    end

    def line_no=(no)
      @line_no = no
    end

    # Reads the next line from this input method.
    #
    # See IO#gets for more information.
    def gets
       unless @line.empty?
 	return @line.shift
       end

      @reidline.init_editor

      begin
	if l = @reidline.get_lines(@prompt)
	  @line = l.split("\n").collect{|e| e+"\n"}
	  @line.shift
	else
	  @eof = true
	  l
	end
      rescue Interrupt
	raise
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

    def_delegator :@reidline, :set_cmpl_proc

    def closed?(lines)
      REI::Fail NotImplementedError, "closed?"
    end

    def set_indent(idx)
      if idx > 1
	i = 0
	@nesting[idx].zip(@nesting[idx-1]) do |n1, n2|
	  break unless n1 == n2
	  i += 1
	end
	if @nesting[idx-1].size > i
	  @reidline.set_indent(idx - 1, i)
	end
      end
    end
  end
end
