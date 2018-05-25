#
#   lex.rb - 
#   	Copyright (C) 1996-2018 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

require "ripper"
require "reirb/token"

module Reirb
  class Lex
    def initialize
      @prev_line_no = @line_no = 1

      @io = nil
      @input = nil
      @scanner = nil
      @scanner_fiber = nil
    end

    attr_reader :prev_line_no
    attr_reader :scanner

    def set_line_no(line_no)
      @line_no = @prev_line_no = line_no
    end

    def prev_char_no
      @scanner.column
    end

    def space_seen?
      @scanner.space_seen?
    end

    alias space_seen space_seen?
    

    def nest
      @scanner.nest
    end

    def set_input(io, p = nil, &block)
      @io = io
      if p.respond_to?(:call)
	@input = p
      elsif block_given?
	@input = block
      else
	@input = Proc.new{@io.gets}
      end

    end

    def set_prompt(p = nil, &block)
      p = block if block_given?
      if p.respond_to?(:call)
	@prompt = p
      else
	@prompt = Proc.new{print p}
      end
    end

    LTYPED = ['"', "'"]

    def prompt
      if nest[-1]&.ltype
	tk = nest[-1]
	case tk
	when StringBegToken
	  ltype = tk.value
	when RegexpBegToken
	  ltype = tk.value
	when SymbegToken
	  ltype = tk.value
	when QSymbolsBegToken
	  ltype = tk.value
	when QWordsBegToken
	  ltype = tk.value
	when EmbexprBegBegToken
	  ltype = tk.value
	else
	  ltype = nil
	end
      end

      if @prompt
	@prompt.call(ltype, nest, @scanner.continue?, @line_no)
      end
    end

    def initialize_input(closing_check: false)
      qio = QIO.new(self) do
	if @scanner.error?
	  Fiber.yield @line
	elsif !@scanner.continue? && @scanner.nest.empty? && !@scanner.seq.empty?
	  Fiber.yield @line
	end
	@scanner.before_gets
	prompt
	l = @input.call
	if l
	  @line_no += 1
	  @line.concat l
	elsif closing_check 
	  Reirb::Fail ParserClosingEOFSupp
	end
	@scanner.after_gets
	l
      end
      @scanner_fiber = Fiber.new do
	begin
	  @scanner = RubyScanner.new(self, qio, "(reirb)", @line_no)
	  prompt
	  @line = ""
	  @scanner.parse
	  Fiber.yield @line
	end while @scanner.error
	nil
      end
    end

    def input_unit
      @line = ""
      @prev_line_no = @line_no
      @scanner_fiber.resume
    end

    class QIO
      def initialize(lex, &block)
	@lex = lex
	@callback = block
      end

      def gets
	@callback.call
      end
    end

    # C.1
    # \n でエラー -> エラー
    # ^Dでエラーなし -> IU
    # ^Dでエラー -> 継続行

    # C.2
    # \n でエラー -> エラー
    # @nesting>0 -> 継続行
    # ignore_nl -> 継続行

    class RubyScanner<Ripper

      PreservedWord = {
	"class"	  => :CLASS, 
	"module"  => :MODULE, 
	"def"	  => :DEF, 
	"undef"	  => :UNDEF, 
	"begin"	  => :BEGIN, 
	"rescue"  => :RESCUE, 
	"mod_rescue" => :MOD_RESCUE, 
	"ensure"  => :ENSURE, 
	"end"	  => :END, 
	"if"	  => :IF, 
	"mod_if"	  => :MOD_IF, 
	"unless"  => :UNLESS, 
	"mod_unless" => :MOD_UNLESS, 
	"then"	  => :THEN, 
	"elsif"	  => :ELSIF, 
	"else"	  => :ELSE, 
	"case"	  => :CASE, 
	"when"	  => :WHEN, 
	"while"	  => :WHILE, 
	"mod_while"  => :MOD_WHILE, 
	"until"	  => :UNTIL, 
	"mod_until"  => :MOD_UNTIL, 
	"for"	  => :FOR, 
	"break"	  => :BREAK, 
	"next"	  => :NEXT, 
	"redo"	  => :REDO, 
	"retry"	  => :RETRY, 
	"raise"	  => :RAISE, 
	"in"	  => :IN, 
	"do"	  => :DO, 
	"return"  => :RETURN, 
	"yield"	  => :YIELD, 
	"super"	  => :SUPER, 
	"self"	  => :SELF, 
	"nil"	  => :NIL, 
	"true"	  => :TRUE, 
	"false"	  => :FALSE, 
	"and"	  => :AND, 
	"or"	  => :OR, 
	"not"	  => :NOT, 
	"alias"	  => :ALIAS, 
	"defined?"=> :DEFINED, 

	"BEGIN"	  => :L_BEGIN, 
	"END"	  => :L_END, 
	"__LINE__"=> :T_LINE__, 
	"__FILE__"=> :T_FILE__, 
      }

      def initialize(lex, src, filename = "(reirb)", lineno = 1)
	@lex = lex
	super(src, filename, lineno)
	@error = nil
	@nest = []
	
	@seq = []
      end

      attr_reader :error
      attr_reader :nest
      attr_reader :seq

      def before_gets
	@ignore_nl = false
      end

      def after_gets
      end
      
      def continue?
#	@ignore_nl
	@seq[-1].kind_of?(IgnoreNLToken)
      end

      def space_seen?
	@seq[-1].kind_of?(SpaceToken)
      end

      def last_state
	@seq[-1] && @seq[-1].state || EXPR_BEG
      end

      def on_default(tok)
	tk = SimpleToken.new(@lex, tok)
	@seq.push tk
      end

      def on_parse_error(*args)
	@error = true
	print "PARSE_ERROR: "
	print [lineno, column], args.inspect, "\n"
      end

      def on_ignored_nl(tok)
#	@ignore_nl = true
	@seq.push SimpleToken.new(@lex, :NL)
	tk = IgnoreNLToken.new(@lex)
	@seq.push tk
      end

      def on_kw(tok)

	w = PreservedWord[tok]
	tk = ReservedWordToken.new(@lex, w)
	case w
	when :BEGIN, :CASE, :CLASS, :DEF, :FOR, :MODULE
	  @nest.push tk
	when :IF, :UNLESS, :UNTIL, :WHILE
	  if last_state.anybits?(EXPR_BEG | EXPR_LABELED)
	    @nest.push tk
	  else
	    w = PreservedWord["mod"+tok]
	    tk = ReservedWordToken.new(@lex, w)
	  end
	when :DO
	  @nest.push tk
	when :END
	  case tk = @nest.pop
	  when ReservedWordToken
	    if tk.token_id.include? [:WHILE, :UNTIL, :FOR]
	      @nest.push tk
	    end
	  end
	end
	@seq.push tk
      end

      def on_while(*args)
	loop do
	  case tk = @nest.pop
	  when ReservedWordToken
	    break if tk.token_id == :WHILE
	  end
	end
      end

      def on_until(*args)
	loop do
	  case tk = @nest.pop
	  when ReservedWordToken
	    break if tk.token_id == :UNTIL
	  end
	end
      end

      def on_for(*args)
	loop do
	  case tk = @nest.pop
	  when ReservedWordToken
	    break if tk.token_id == :FOR
	  end
	end
      end

      def on_lparen(tok)
	tk = SimpleToken.new(@lex, :LPARLEN)
	@seq.push tk
	@nest.push tk
      end

      def on_rparen(tok)
	tk = SimpleToken.new(@lex, :RPARLEN)
	@seq.push tk
	@nest.pop
      end

      def on_lbracket(tok)
	tk = SimpleToken.new(@lex, :LBRACKET)
	@seq.push tk
	@nest.push tk
      end

      def on_rbracket(tok)
	tk = SimpleToken.new(@lex, :RBRACKET)
	@seq.push tk
	@nest.pop
      end

      def on_lbrace(tok)
	tk = SimpleToken.new(@lex, :LBRACE)
	@seq.push tk
	@nest.push tok
      end

      def on_rbrace(tok)
	tk = SimpleToken.new(@lex, :RBRACE)
	@seq.push tk
	@nest.pop
      end

      def on_tstring_beg(tok)
	tk = StringBegToken.new(@lex, tok)
	tk.ltype = true
	@seq.push tk
	@nest.push tk
      end

      def on_tstring_end(tok)
	tk = StringEndToken.new(@lex, tok)
	@nest.pop
      end

      def on_regexp_beg(tok)
	tk = RegexpBegToken.new(@lex, tok)
	tk.ltype = true
	@seq.push tk
	@nest.push tk
      end

      def on_regexp_end(tok)
	@nest.pop
      end

      def on_symbeg(tok)
	tk = SymbegToken.new(@lex, tok)
	@seq.push tk
	if tok != ":"
	  tk.ltype = true
	  @nest.push tk
	end
      end

      def on_qsymbols_beg(tok)
	tk = QSymbolsBegToken.new(@lex, tok)
	tk.ltype = true
	@seq.push tk
	@nest.push tk
      end

      def on_qwords_beg(tok)
	tk = QWordsBegToken.new(@lex, tok)
	tk.ltype = true
	@seq.push tk
	@nest.push tk
      end

      def on_embexpr_beg(tok)
	tk = EmbexprBegBegToken.new(@lex, tok)
	@seq.push tk
	@nest.push tk
      end

      def on_embexpr_end(tok)
	@nest.pop
      end

      (SCANNER_EVENTS.map {|event|:"on_#{event}"} - instance_methods(false)).each do |event|
	alias_method event, :on_default
      end


    end

  end
end
  
  

  

