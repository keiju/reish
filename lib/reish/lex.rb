#
#   reish/lex.rb - 
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
    Debug = false

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

    PreservedWordH = {
#      "rescue"	=> :RESCUE, 
#      "ensure"	=> :ENSURE, 
      "end"	=> :END, 
      "then"	=> :THEN, 
      "elsif"	=> :ELSIF, 
      "else"	=> :ELSE, 
      "when"	=> :WHEN, 
#      "break"	=> :BREAK, 
#      "next"	=> :NEXT, 
#      "redo"	=> :REDO, 
#      "retry"	=> :RETRY, 
      "in"	=> :IN, 
      "do"	=> :DO, 
#      "return"	=> :RETURN, 
#      "yield"	=> :YIELD, 
#      "super"	=> :SUPER, 
      "self"	=> :SELF, 
      "nil"	=> :NIL, 
      "true"	=> :TRUE, 
      "false"	=> :FALSE, 
#      "and"	=> :AND, 
#      "or"	=> :OR, 
#      "not"	=> :NOT, 
#      "defined?"=> :DEFINED, 
    }

    PseudoVars = [
      :NIL,
      :TRUE,
      :FALSE,
      :SELF,
    ]

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
      :DO_COND => :EXPR_BEG,
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

      @lex_state = EXPR_BEG

      @cond_stack = []
    end

#    attr_accessor :lex_state
    def lex_state=(v)
#      puts "LEX STATE CHANGE: #{v}"
      @lex_state = v
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

    def prompt
      @ruby_scanner.prompt
    end

    def initialize_input
      @ltype = nil
      @quoted = nil
      @indent = 0
      @indent_stack = []
      @lex_state = EXPR_BEG
      @space_seen = false
      @here_header = false

      @continue = false
      prompt

      @line = ""
      @exp_line_no = @line_no
    end

    def token
      @prev_seek = @ruby_scanner.seek
      @prev_line_no = @ruby_scanner.line_no
      @prev_char_no = @ruby_scanner.char_no
      nl_seen =false
      last_nl = false
      begin
	begin
	  tk = @OP.match(@ruby_scanner)
	  @space_seen = tk.kind_of?(SpaceToken)
	  last_nl = (tk.token_id == :NL)
	rescue SyntaxError
	  raise if @exception_on_syntax_error
	  tk = ErrorToken.new(@io, @prev_seek, @prev_line_no, @prev_char_no)
	end

#	puts "TOKEN: #{tk.inspect}"
      end while tk.kind_of?(SpaceToken) || nl_seen
      nl_seen = last_nl
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
      @space_seen = true
	while io.getc =~ /[ \t\f\r\13]/; end
	io.ungetc
	SpaceToken.new(io, @prev_seek, @prev_line_no, @prev_char_no)
      end

      @OP.def_rule("\n") do
	|op, io|
	self.lex_state = EXPR_BEG
	SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, :NL)
      end

      @OP.def_rules("=") do
      |op, io|

	ReservedWordToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, "=")
      end

      @OP.def_rule("=>") do
	|op, io|
	SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, :ASSOC)
      end
		   

      @OP.def_rules("'", '"') do
	|op, io|
	identify_string(op, io)
      end

      @OP.def_rule("(") do
	|op, io|
	cond_push(false)
	self.lex_state = EXPR_BEG
	SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, op)
      end

       @OP.def_rule("[") do
 	|op, io|

	if @lex_state == EXPR_BEG
	  self.lex_state = EXPR_ARG
	  SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, :LBLACK_A)
	elsif @space_seen
	  io.ungetc
	  identify_wildcard(io)
	else
	  SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, :LBLACK_I)
	end
      end

      @OP.def_rule("{") do
 	|op, io|

	if @lex_state == EXPR_BEG
	  self.lex_state = EXPR_ARG
	  SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, :LBRACE_H)
	elsif @space_seen
	  io.ungetc
	  identify_wildcard(io)
	else
	  SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, :LBRACE_I)
	end
      end

#       @OP.def_rule("{") do
# 	|op, io|
# 	cond_push(false)
# 	self.lex_state = EXPR_BEG
# 	SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, op)
#       end


#      @OP.def_rules("]", ")", "}") do
      @OP.def_rules("]", ")", "}") do
	|op, io|
	cond_lexpop
	SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, op)
      end

      @OP.def_rule("!") do
	|op, io|
	self.lex_state = EXPR_BEG
	ReservedWordToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, :BANG)
      end

      @OP.def_rule("|") do
	|op, io|
	self.lex_state = EXPR_BEG
	ReservedWordToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, '|')
      end

      @OP.def_rule("::") do
	|op, io|
	self.lex_state = EXPR_BEG
	ReservedWordToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, :COLON2)
      end

      @OP.def_rule(".") do
 	|op, io|

	if @lex_state == EXPR_BEG
	  self.lex_state = EXPR_ARG
	  SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, :DOT_COMMAND)
	elsif @space_seen
	  io.ungetc
	  identify_word(io)
	else
	  self.lex_state = EXPR_BEG
	  SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, ".")
	end
      end

      @OP.def_rule(";") do
	|op, io|
	self.lex_state = EXPR_BEG
	SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, ';')
      end


      @OP.def_rule("&") do
	|op, io|
	self.lex_state = EXPR_BEG
	tk = SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, '&')
      end

      @OP.def_rule("&&") do
	|op, io|
	self.lex_state = EXPR_BEG
	SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, :AND_AND)
      end

      @OP.def_rule("||") do
	|op, io|
	self.lex_state = EXPR_BEG
	SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, :OR_OR)
      end

      @OP.def_rule("$[") do
 	|op, io|
 	cond_push(false)
 	self.lex_state = EXPR_ARG
 	SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, :LBLACK_A)
      end

      @OP.def_rule("${") do
 	|op, io|
 	cond_push(false)
 	self.lex_state = EXPR_ARG
 	SimpleToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, :LBRACE_H)
      end

      @OP.def_rule("$(") do
	|op, io|
	io.ungetc
	identify_compstmt(io, RubyToken::TkRPAREN)
      end

      @OP.def_rule("$/") do
	|op, io|
	identify_regexp("/", io)
      end

      @OP.def_rule(">") do
	|op, io|
	ReservedWordToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, '>')
      end

      @OP.def_rule("") do
	|op, io|

	if /[0-9]/ =~ io.peek(0) 
	  identify_number(io)
	elsif @lex_state == EXPR_BEG
	  identify_id(io)
	else
	  identify_word(io)
	end
      end
    end

    def identify_compstmt(io, close)
      exp = @ruby_scanner.identify_compstmt(close)
      
      RubyExpToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, exp)
    end

    def identify_id(io)
      token = ""

      while /[[:graph:]]/ =~ (ch = io.getc) && /[=\|&;\(\)<>\[\{\}\]]/ !~ ch
	print ":", ch, ":" if Debug

	if ch == "/"
	  io.ungetc
	  return identify_path(io, token)
	end
	token.concat ch
      end
      io.ungetc

      if tid = PreservedWord[token]
	identify_reserved_word(io, token, tid)
      else
	self.lex_state = EXPR_ARG
	IDToken.new(io, @prev_seek, @prev_line_no ,@prev_char_no, token)
      end
    end

    def identify_path(io, token = "")
      while /[[:graph:]]/ =~ (ch = io.getc) && /[\|&;\(\)<>]/ !~ ch
	print ":", ch, ":" if Debug

	token.concat ch
      end
      io.ungetc

      self.lex_state = EXPR_ARG
      PathToken.new(io, @prev_seek, @prev_line_no ,@prev_char_no, token)
    end

    def identify_word(io, token = "")
      while /[[:graph:]]/ =~ (ch = io.getc) && /[\|&;\(\)<>\}\]]/ !~ ch
	print ":", ch, ":" if Debug

	break if ch == "=" && io.peek(0) == ">"

	if /[\[\{\*]/ =~ ch
	  io.ungetc
	  return identify_wildcard(io, token)
	end
	token.concat ch
      end
      io.ungetc

      if PreservedWordH[token]

	if tid = PreservedWord[token]
	  identify_reserved_word(io, token, tid)
	else
	  self.lex_state = EXPR_ARG
	  IDToken.new(io, @prev_seek, @prev_line_no ,@prev_char_no, token)
	end
      else
	WordToken.new(io, @prev_seek, @prev_line_no ,@prev_char_no, token)
      end
    end

    def identify_reserved_word(io, token = "", tid = nil)
      tid = PreservedWordH[token] unless tid

      if tid == :DO && cond?
	tid = :DO_COND
      end
	  
      if st = TransState[tid]
	self.lex_state = st
      end

      if PseudoVars.include?(tid)
	self.lex_state = EXPR_END
	PseudoVariableToken.new(io, @prev_seek, @prev_line_no ,@prev_char_no, token)
      else
	ReservedWordToken.new(io, @prev_seek, @prev_line_no ,@prev_char_no, tid)
      end
    end

    def identify_wildcard(io, token = "")
      
      while /[[:graph:]]/ =~ (ch = io.getc) && /[\|&;\(\)<>]/ !~ ch
	print ":", ch, ":" if Debug
	token.concat ch
      end
      io.ungetc

      WildCardToken.new(io, @prev_seek, @prev_line_no ,@prev_char_no, token)
    end

    def identify_number(io, token = "")
      if io.peek(0) == "0" && io.peek(1) !~ /[.eE]/
	token.concat io.getc
	case ch = io.peek(0)
	when /[xX]/
	  ch = io.getc
	  token.concat ch
	  match = /[0-9a-fA-F_]/
	when /[bB]/
	  ch = io.getc
	  token.concat ch
	  match = /[01_]/
	when /[oO]/
	  ch = io.getc
	  token.concat ch
	  match = /[0-7_]/
	when /[dD]/
	  ch = io.getc
	  token.concat ch
	  match = /[0-9_]/
	when /[0-7]/
	  match = /[0-7_]/
	when /[89]/
	  return identify_word(io, token)
	else
	  if @lex_state == EXPR_BEG && (/\s/ =~ ch || /[\|&;\(\)<>\{\[\}\]\.\:]/ =~ ch)
	    self.lex_state = EXPR_END
	    return IntegerToken.new(io, @prev_seek, @prev_line_no ,@prev_char_no, token)
	  elsif  /\s/ !~ ch && /[\|&;\(\)<>\}\]]/ !~ ch
	    return identify_word(io, token)
	  else
	    self.lex_state = EXPR_END
	    return IntegerToken.new(io, @prev_seek, @prev_line_no ,@prev_char_no, token)
	  end
	end

	len0 = true
	non_digit = false
	while ch = io.getc
	  if match !~ ch
	    unless len0
	      io.ungetc
	      break
	    end

	    token.concat ch
	    return identify_word(io, token)
	  end
	    
	  if ch == "_"
	    if non_digit
	      token.concat ch
	      return identify_word(io, token)
	    else
	      non_digit = ch
	    end
	  else
	    non_digit = false
	    len0 = false
	  end
	  token.concat ch
	end
	self.lex_state = EXPR_END
	return IntegerToken.new(io, @prev_seek, @prev_line_no ,@prev_char_no, token)
      end

      token_type = IntegerToken
      allow_point = true
      allow_e = true
      non_digit = false
      while ch = io.getc
	case ch
	when /[0-9]/
	  token.concat ch
	  non_digit = false
	when "_"
	  token.concat ch
	  non_digit = ch
	when allow_point && "."
	  token.concat ch
	  if non_digit
	    return identify_word(io, token)
	  end
	  token_type = NumberToken
	  if io.peek(0) !~ /[0-9]/
	    return identify_word(io, token)
	  end
	  allow_point = false
	when allow_e && "e", allow_e && "E"
	  if non_digit
	    token.concat ch
	    return identify_word(io, token)
	  end
	  token.concat ch
	  token_type = NumberToken
	  if io.peek(0) =~ /[+-]/
	    token.concat io.getc
	  end
	  allow_e = false
	  allow_point = false
	  non_digit = ch
	else
	  if /\s/ =~ ch || /[\|&;\(\)<>\}\]]/ =~ ch
	    io.ungetc
	    break
	  end
	  token.concat ch
	  return identify_word(io, token)
	end
      end
      if @lex_state != EXPR_BEG && token_type==IntegerToken && /[<>]/ =~ io.peek(0)
	return FidToken.new(io, @prev_seek, @prev_line_no ,@prev_char_no, token)
      end
      self.lex_state = EXPR_END
      token_type.new(io, @prev_seek, @prev_line_no ,@prev_char_no, token)
    end

    def identify_string(op, io)
      str = @ruby_scanner.identify_reish_string(op)
      self.lex_state = EXPR_END
      StringToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, str)
    end

    def identify_regexp(op, io)
p "XXXX"
p op
      str = @ruby_scanner.identify_reish_string(op)
      self.lex_state = EXPR_END
      RegexpToken.new(io, @prev_seek, @prev_line_no, @prev_char_no, str)
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

    


