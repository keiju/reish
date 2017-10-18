#
#   reish/input-method/input-method.rb - input methods used irb
#                         oroginal version from irb.
#   	Copyright (C) 2014-2017 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
require "forwardable"

require 'reish/src_encoding'
require 'reish/magic-file'

require "reish/reidline"

module Reish
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

      @lex = Lex.new
      @parser = Parser.new(@lex)
      @parser.input_closed = true
      @in_queue = Queue.new
      @out_queue = Queue.new
      @im = QueueInputMethod.new(nil, @in_queue)

      @lex.set_prompt do |ltype, indent, continue, line_no|
	idx = line_no - @line_no
	@nesting[idx] = indent.dup
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

	if @promptor
	  @reidline.set_prompt(idx, @promptor.call(line_no, indent, ltype, continue), indent.size)
	end
      end

      @lex.set_input(@im){@im.gets}
      start_closing_checker
      @reidline.set_closed_proc &method(:closed?)
    end

    attr_accessor :completor
    attr_accessor :promptor

    def line_no=(no)
      @line_no = no
    end

    # Reads the next line from this input method.
    #
    # See IO#gets for more information.
    def gets
      #        Readline.input = @stdin
      #        Readline.output = @stdout

      #	Readline.completion_proc = @completor.completion_proc if @completor

      @reidline.init_editor

#      @gets_mx.synchronize do
#	@gets_start = true
#	@gets_cv.broadcast
#      end

      begin
	if l = @reidline.get_lines(@prompt)
	  #          HISTORY.push(l) if !l.empty?
	  #@line[@line_no += 1] = l + "\n"
#	  @line[@line_no + 1] =  l + "\n"
	  l
	else
	  @eof = true
	  l
	end
      rescue Interrupt
#	completion_cheker_reset
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

    def start_closing_checker
      @gets_start = false
      @gets_mx = Mutex.new
      @gets_cv = ConditionVariable.new

      @closing_checker = Thread.start{
	loop do 
	  begin
	    @gets_mx.synchronize do
	      until @gets_start
		@gets_cv.wait(@gets_mx)
	      end
	      @gets_start = false
	    end
	    @nesting = []
	    @lex.set_line_no(@line_no)
	    @lex.initialize_input
	    @exc = nil
	    while !@in_queue.empty?
	      @parser.do_parse
	    end
	    @out_queue.push true

	  rescue ParserClosingSupp, ParserClosingEOFSupp
	    @exc = $!
	    @out_queue.push false

	  rescue Racc::ParseError
	    @exc = $!
	    @reidline.message($!.message)
	    @out_queue.push false

	  rescue
	    @exc = $!
	    begin
	      @reidline.message($!.message)
	      @reidline.message($!.backtrace.join("\n"), append: true)
	    rescue
	      puts "Reidline abort on exeption!!"
	      puts "Original Exception"
	      p @exc
	      puts "Reidline Exception"
	      p $!
	    end
	    @out_queue.push false
	  ensure
	    @in_queue.clear
	  end
	end
      }

    end

    def resume_closing_checker
      @gets_mx.synchronize do
	@gets_start = true
	@gets_cv.broadcast
      end
    end

    def closed?(lines)
      ret = nil
      begin
	lines.each do |line| 
	  @in_queue.push line+"\n"
	end
	resume_closing_checker
	
	@in_queue.push nil
	ret = @out_queue.pop
 	if !ret && @exc && @parser.err_token
 	  for l in @parser.err_token.line_no + 1 .. @line_no + lines.size do
 	    @reidline.set_prompt(l - @line_no, @promptor.call(l, "", nil, nil))
 	  end
 	end

	@in_queue.clear
	@out_queue.clear
      ensure
      end
      ret
    end

  end
end
