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
    def initialize(closing_check: false)
      @closing_check = closing_check

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

    def initialize_input
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
	elsif @closing_check 
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
	  begin
	    @scanner.parse
	  rescue ParseError=>exc
#	    raise if @closing_check
	    Fiber.yield exc
	    redo
	  rescue Interrupt=>exc
	    Fiber.yield exc
	    redo
	  end
	  Fiber.yield @line
	end while @scanner.error
	nil
      end
    end

    def input_unit
      @line = ""
      @prev_line_no = @line_no
      r = @scanner_fiber.resume
      case r 
      when nil
	nil
      when ParseError
	raise r if @closing_check
	@line
      when Exception
	raise r
      else
	@line
      end
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
	@cond_stack = []
	
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
	tk
      end

      def on_parse_error(*args)
	@error = true
	exc = ParseError.new(args)
	exc.line_no = lineno
	exc.column = column
	
	raise exc
      end

      def on_nl(tok)
	on_default(tok)
	until @cond_stack.empty? ||
	    [:LPALEN, :LBRACKET, :LBRACE,].include?(@cond_stack.last.token_id)
          @cond_stack.pop
        end
      end

      def on_ignored_nl(tok)
#	@ignore_nl = true
	@seq.push SimpleToken.new(@lex, :NL)
	tk = IgnoreNLToken.new(@lex)
	@seq.push tk
      end

      def on_semicolon(tok)
	on_default(tok)
	until @cond_stack.empty? ||
	    [:LPALEN, :LBRACKET, :LBRACE,].include?(@cond_stack.last.token_id)
          @cond_stack.pop
        end
      end

      def on_kw(tok)
	w = PreservedWord[tok]
	tk = ReservedWordToken.new(@lex, w)
	case w
	when :BEGIN, :CASE, :CLASS, :DEF, :FOR, :MODULE
	  @nest.push tk
	  @cond_stack.push tk
	when :IF, :UNLESS, :UNTIL, :WHILE
	  if last_state.anybits?(EXPR_BEG | EXPR_LABELED)
	    @nest.push tk
	    @cond_stack.push tk
	  else
	    w = PreservedWord["mod"+tok]
	    tk = ReservedWordToken.new(@lex, w)
	  end
	when :ELSE, :WHEN, :RESCUE, :ENSURE
	  @nest.pop
	  @nest.push tk
	when :ELSIF
	  @nest.pop
	  @nest.push tk
	  @cond_stack.pop
	  @cond_stack.push tk
	when :DO
	  if ![:FOR, :WHILE, :UNTIL].include?(@cond_stack.last&.token_id)
	    @nest.push tk
	    @cond_stack.push tk
	  end
	when :END
	  if [:FOR, :WHILE, :UNTIL].include? (tk = @nest.pop)&.token_id
	    @nest.push tk
	  else
	    @cond_stack.pop
	  end
	end
	@seq.push tk
      end

      def on_while(*args)
	while @nest.pop&.token_id == :WHILE; end
	while @cond_stack.pop&.token_id == :WHILE; end
      end

      def on_until(*args)
	while @nest.pop&.token_id == :UNTIL; end
	while @cond_stack.pop&.token_id == :UNTIL; end
      end

      def on_for(*args)
	while @nest.pop&.token_id == :FOR; end
	while @cond_stack.pop&.token_id == :FOR; end
      end

      def on_lparen(tok)
	tk = on_default(:LPARLEN)
	@nest.push tk
	@cond_stack.push tk
      end

      def on_rparen(tok)
	on_default(:RPARLEN)
	@nest.pop
	@cond_stack.pop
      end

      def on_lbracket(tok)
	tk = on_default(:LBRACKET)
	@nest.push tk
	@cond_stack.push tk
      end

      def on_rbracket(tok)
	on_default(:RBRACKET)
	@nest.pop
	@cond_stack.pop
      end

      def on_lbrace(tok)
	tk = on_default(:LBRACE)
	@nest.push tok
	@cond_stack.push tk
      end

      def on_rbrace(tok)
	on_default(:RBRACE)
	@nest.pop
	@cond_stack.pop
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
	tk = EmbexprBegToken.new(@lex, tok)
	@seq.push tk
	@nest.push tk
      end

      def on_embexpr_end(tok)
	tk = EmbexprEndToken.new(@lex, tok)
	@seq.push tk
	@nest.pop
      end

      (SCANNER_EVENTS.map {|event|:"on_#{event}"} - instance_methods(false)).each do |event|
	alias_method event, :on_default
      end


    end

  end
end
  
  

  

