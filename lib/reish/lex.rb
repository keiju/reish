#
#   lex.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	by Keiju ISHITSUKA(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

require "irb/ruby-lex"
require "reish/token"

module Reish
  class Lex
    Debug = true

    PreservedWord = {
      "class"	=> :CLASS, 
      "module"	=> :MODULE, 
      "def"	=> :DEF, 
      "undef"	=> :UNDEF, 
      "begin"	=> :BEGIN, 
      "rescue"	=> :RESCUE, 
      "ensure"	=> :ENSURE, 
      "end"	=> :END, 
      "if"	=> :IF, 
      "unless"	=> :UNLESS, 
      "then"	=> :THEN, 
      "elsif"	=> :ELSIF, 
      "else"	=> :ELSE, 
      "case"	=> :CASE, 
      "when"	=> :WHEN, 
      "while"	=> :WHILE, 
      "until"	=> :UNTIL, 
      "for"	=> :FOR, 
      "break"	=> :BREAK, 
      "next"	=> :NEXT, 
      "redo"	=> :REDO, 
      "retry"	=> :RETRY, 
      "in"	=> :IN, 
      "do"	=> :DO, 
      "return"	=> :RETURN, 
      "yield"	=> :YIELD, 
      "super"	=> :SUPER, 
      "self"	=> :SELF, 
      "nil"	=> :NIL, 
      "true"	=> :TRUE, 
      "false"	=> :FALSE, 
      "and"	=> :AND, 
      "or"	=> :OR, 
      "not"	=> :NOT, 
      "alias"	=> :ALIAS, 
      "defined?"=> :DEFINED, 

      "BEGIN"	=> :L_BEGIN, 
      "END"	=> :L_END, 
      "__LINE__"=> :T_LINE__, 
      "__FILE__"=> :T_FILE__, 

      "!"       => :BANG,
    }

    TransState = {
      :CLASS => :EXPR_CLASS,
      :MODULE => :EXPR_BEG,
      :DEF => :EXPR_FNAME,
      :UNDEF => :EXPR_FNAME,
      :BEGIN => :EXPR_BEG,
      :RESCUE =>  :EXPR_MID,
      :ENSURE => :EXPR_BEG,
      :END => :EXPR_END,
      :IF => :EXPR_BEG,
      :UNLESS => :EXPR_BEG,
      :THEN => :EXPR_BEG,
      :ELSIF => :EXPR_BEG,
      :ELSE => :EXPR_BEG,
      :CASE => :EXPR_BEG,
      :WHEN => :EXPR_BEG,
      :WHILE => :EXPR_BEG,
      :UNTIL => :EXPR_BEG,
      :FOR => :EXPR_BEG,
      :BREAK => :EXPR_END,
      :NEXT => :EXPR_END,
      :REDO => :EXPR_END,
      :RETRY => :EXPR_END,
      :IN => :EXPR_BEG,
      :DO => :EXPR_BEG,
      :RETURN => :EXPR_MID,
      :YIELD => :EXPR_END,
      :SUPER => :EXPR_END,
      :SELF =>  :EXPR_END,
      :NIL => :EXPR_END,
      :TRUE => :EXPR_END,
      :FALSE => :EXPR_END,
      :AND => :EXPR_BEG,
      :OR => :EXPR_BEG,
      :NOT => :EXPR_BEG,
      :ALIAS => :EXPR_FNAME,
      :DEFINED => :EXPR_END,
      :BEGIN => :EXPR_END,
      :L_END => :EXPR_END,
      :T__LINE__ => :EXPR_END,
      :T__FILE__ => :EXPR_END,
    }

    def initialize
      lex_init
      @ruby_scanner = RubyLex.new
      @ruby_scanner.exception_on_syntax_error = false
      @io = STDIN

      @lex_state = :EXPR_BEG

      @cond_stack = []
    end

    def cond_push(v=true)
      @cond_stack.push v
    end

    def cond_pop
      @cond_stack.shift
    end

    def cond_lexpop
      v = @cond_stack.shift
      @cond_stak[0] = true if v
    end

    def cond?
      @cond_stack.last
    end

    def set_input(io, p = nil, &block)
      @io = io
      @ruby_scanner.set_input(io, p, &block)
    end

    def set_prompt(&block)
      @ruby_scanner.set_prompt &block
    end

    def token
      @prev_seek = @ruby_scanner.seek
      @prev_line_no = @ruby_scanner.line_no
      @prev_char_no = @ruby_scanner.char_no
      begin
	begin
	  tk = @OP.match(@ruby_scanner)
	rescue SyntaxError
	  raise if @exception_on_syntax_error
	  tk = ErrorToken.new(@io, @prev_seek, @prev_line_no, @prev_char_no)
	end

	puts "TOKEN: #{tk.inspect}"
      end while tk.kind_of?(SpaceToken)
      tk = EOFToken.new(@io, @prev_seek, @prev_line_no, @prev_char_no) unless tk
      @ruby_scanner.get_readed
      tk
    end

    def racc_token
      tk = token
      [tk.token_id, tk]
    end

    def lex_init
      @OP = IRB::SLex.new

      @OP.def_rules("\0", "\004", "\032") do |op, io|
	EOFToken.new(io, @prev_seek, @prev_line_no, @prev_char_no)
      end

      @OP.def_rules(" ", "\t", "\f", "\r", "\13") do |op, io|
	while io.getc =~ /[ \t\f\r\13]/; end
	io.ungetc
	SpaceToken.new(io, @prev_seek, @prev_line_no, @prev_char_no)
      end

      @OP.def_rule("\n") do
	|op, io|
	SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, op)
      end

      @OP.def_rules("'", '"') do
	|op, io|
	str = @ruby_scanner.identify_reish_string(op)
	WordToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, str)
      end

      @OP.def_rule("(") do
	|op, io|
	cond_push(false)
	SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, op)
      end

      @OP.def_rule("[") do
	|op, io|
	cond_push(false)
	SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, op)
      end

      @OP.def_rule("{") do
	|op, io|
	cond_push(false)
	SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, op)
      end

      @OP.def_rules("]", ")", "}") do
	|op, io|
	cond_lexpop
	SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, op)
      end

      @OP.def_rule("!") do
	|op, io|
	ReservedWordToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, :BANG)
      end

      @OP.def_rule("|") do
	|op, io|
	ReservedWordToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, '|')
      end

      @OP.def_rule(">") do
	|op, io|
	ReservedWordToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, '>')
      end

      @OP.def_rule(";") do
	|op, io|
	SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, ';')
      end


      @OP.def_rule("&") do
	|op, io|
	tk = SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, '&')
      end

      @OP.def_rule("&&") do
	|op, io|
	SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, :AND_AND)
      end

      @OP.def_rule("||") do
	|op, io|
	SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, :OR_OR)
      end

      @OP.def_rule("$(") do
	|op, io|
	io.ungetc
	identify_compstmt(io, RubyToken::TkRPAREN)
      end

      @OP.def_rule("$[") do
	|op, io|
	io.ungetc
	identify_compstmt(io, RubyToken::TkRBRACK)
      end

      @OP.def_rule("") do
	|op, io|

	identify_word(io)
      end
    end

    def identify_compstmt(io, close)
      exp = @ruby_scanner.identify_compstmt(close)
      
      RubyExpToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, exp)
    end

    def identify_word(io)
      token = ""

      while (ch = io.getc) =~ /[\w\/\.]/
	print ":", ch, ":" if Debug
	token.concat ch
      end
      io.ungetc

      if tid = PreservedWord[token]
	if tid == :DO && cond?
	  tid = :COND_DO
	end
	ReservedWordToken.new(io, @prev_seek, @prev_line_no ,@prev_char_no, tid)
      else
	IDToken.new(io, @prev_seek, @prev_line_no ,@prev_char_no, token)
      end
    end
  end
end

class RubyLex
  def identify_compstmt(term)
    initialize_input
    get_readed

    loop do
      @continue = false
      prompt
      tk = token
      if @ltype or @continue or @indent > 0
	next
      end
      break if tk.kind_of?(term)
    end
    get_readed
  end

  def identify_reish_string(ltype, quoted = ltype)
    
    initialize_input
    get_readed

    @ltype = ltype
    @quoted = quoted
    subtype = nil
    begin
      nest = 0
      while ch = getc
	if @quoted == ch and nest == 0
	  ungetc
	  str = get_readed
	  getc
	  break
	elsif ch == "#" and peek(0) == "{"
	  identify_reish_string_dvar
	elsif @ltype != "'" && @ltype != "]" && @ltype != ":" and ch == "#"
	  subtype = true
	elsif ch == '\\' and @ltype == "'" #'
	  case ch = getc
	  when "\\", "\n", "'"
	  else
	    ungetc
	  end
	elsif ch == '\\' #'
	  read_escape
	end
	if PERCENT_PAREN.values.include?(@quoted)
	  if PERCENT_PAREN[ch] == @quoted
	    nest += 1
	  elsif ch == @quoted
	    nest -= 1
	  end
	end
      end
      if @ltype == "/"
	if peek(0) =~ /i|m|x|o|e|s|u|n/
	  getc
	end
      end
      if subtype
	Token(DLtype2Token[ltype])
      else
	Token(Ltype2Token[ltype])
      end
      str
    ensure
      @ltype = nil
      @quoted = nil
      @lex_state = EXPR_END
    end
  end

  def identify_reish_string_dvar
    begin
      getc

      reserve_continue = @continue
      reserve_ltype = @ltype
      reserve_indent = @indent
      reserve_indent_stack = @indent_stack
      reserve_state = @lex_state
      reserve_quoted = @quoted

      @ltype = nil
      @quoted = nil
      @indent = 0
      @indent_stack = []
      @lex_state = EXPR_BEG
      
      loop do
	@continue = false
	prompt
	tk = token
	if @ltype or @continue or @indent > 0
	  next
	end
	break if tk.kind_of?(TkRBRACE)
      end
    ensure
      @continue = reserve_continue
      @ltype = reserve_ltype
      @indent = reserve_indent
      @indent_stack = reserve_indent_stack
      @lex_state = reserve_state
      @quoted = reserve_quoted
    end
  end

end

    


