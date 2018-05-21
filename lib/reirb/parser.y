#
#   reirb/parser.y - 
#   	Copyright (C) 2014-2018 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

class Reirb::Parser

  preclow
    nonassoc LOWER
    nonassoc LBRACE_ARG

    nonassoc  MOD_IF MOD_UNLESS MOD_WHILE MOD_UNTIL
    left  OR AND
    right NOT
    nonassoc DEFINED
    right '=' ASGN
    left MOD_RESCUE
    right '?' ':'
    nonassoc DOT2 DOT3
    left  OR_OR
    left  AND_AND
    nonassoc  CMP EQ EQQ NEQ MATCH NMATCH
    left  '>' GEQ '<' LEQ
    left  '|' '^'
    left  '&'
    left  LSHFT RSHFT
    left  '+' '-'
    left  '*' '/' '%'
    right UMINUS_NUM UMINUS
    right POWER
    right '!' BANG '~' UPLUS
    noassoc HIGHER
  prechigh


  rule
  inputunit: simple_list simple_list_terminator
	    {
		@lex.continue = false
		_values.push Node::InputUnit(val[0], val[1])
	        yyaccept
	    }
	| NL
	    {
		@lex.continue = false
		_values.push Node::NOP
  		yyaccept
	    }
      	| EOF
	    {
                _values.push Node::EOF
		yyaccept
	    }
  
  simple_list: simple_list1
	| simple_list1 ';'

  simple_list1:	top_stmt
	    {
		result = Node::Sequence(val[0])
            }
  	| simple_list1 ";" top_stmt
	    { 
		val[0].add_command(val[2])
		result = val[0]
	    }

  simple_list_terminator:	NL
	| EOF

  top_compstmt: top_stmts opt_terms

  top_stmts: 
	| top_stmt
	| top_stmts terms top_stmt
	| error top_stmt

  top_stmt: stmt
	| BEGIN begin_block

  begin_block: '{' top_compstmt '}'

  compstmt: stmts opt_terms

  stmts: 
	| stmt_or_begin
	| stmts terms stmt_or_begin
	| error stmt

  stmt_or_begin: stmt
	| BEGIN begin_block

  stmt : alias_command
	| undef_command
	| stmt MOD_IF expr
	| stmt MOD_UNLESS expr
	| stmt MOD_WHILE expr
        | stmt MOD_UNTIL expr
	| stmt MOD_RESCUE stmt
	| keyword_END '{' compstmt '}'
	| command_asgn
#	| mlhs '=' command_call
	| lhs '=' mrhs
#	| mlhs '=' mrhs_arg
	| expr

  expr: command_call
	| expr AND opt_nl expr
	| expr OR opt_nl expr
 	| BANG expr
 	| NOT expr
	| arg

  args: arg
	| STAR arg
	| args ',' arg
	| args ',' STAR arg

  arg: lhs '=' arg_rhs
	| var_lhs ASGN arg_rhs
	| primary '[' opt_call_args rbracket ASGN arg_rhs
	| primary call_op IDENTIFIER ASGN arg_rhs
	| primary call_op CONSTANT ASGN arg_rhs
	| primary tCOLON2 IDENTIFIER ASGN arg_rhs
	| primary tCOLON2 CONSTANT ASGN arg_rhs
	| COLON3 CONSTANT ASGN arg_rhs
	| backref ASGN arg_rhs
	| arg DOT2 arg
	| arg DOT3 arg
	| arg '+' arg
	| arg '-' arg
	| arg '*' arg
	| arg '/' arg
	| arg '%' arg
	| arg POWER arg
	| UMINUS_NUM simple_numeric POWER arg
	| UPLUS arg
	| UMINUS arg
	| arg '|' arg
	| arg '^' arg
	| arg '&' arg
	| arg CMP arg
      	| rel_expr	      =CMP
	| arg EQ arg
	| arg EQQ arg
	| arg NEQ arg
	| arg MATCH arg
	| arg NMATCH arg
	| '!' arg
	| '~' arg
	| arg LSHFT arg
	| arg RSHFT arg
	| arg AND_AND arg
	| arg OR_OR arg
	| DEFINED opt_nl arg
	| arg '?' arg opt_nl ':' arg
	| primary

  arg_rhs: arg   =ASGN
	| arg MOD_RESCUE arg

  primary: literal
	| strings
	| xstring
	| regexp
	| words
	| qwords
	| symbols
	| qsymbols
	| var_ref
	| backref
	| FID
	| BEGIN bodystmt END
	| LPAREN_ARG rparen
	| LPAREN_ARG stmt rparen
	| LPAREN compstmt ')'
	| primary COLON2 CONSTANT
	| COLON3 CONSTANT
	| LBRACK aref_args ']'
	| LBRACE assoc_list '}'
	| RETURN
	| YIELD '(' call_args rparen
	| YIELD '(' rparen
	| YIELD
	| DEFINED opt_nl '(' expr rparen
	| NOT '(' expr rparen
	| NOT '(' rparen
	| fcall brace_block
        | method_call
	| method_call brace_block
	| LAMBDA lambda
	| IF expr then compstmt if_tail END
	| UNLESS expr then compstmt opt_else END
	| WHILE expr_do compstmt END
	| UNTIL expr_do compstmt END
	| CASE expr opt_terms case_body END
	| CASE opt_terms case_body END
	| FOR for_var keyword_in expr _do compstmt END
	| CLASS cpath superclass bodystmt END
	| CLASS tLSHFT expr term bodystmt END
	| MODULE cpath bodystmt END
	| DEF fname f_arglist bodystmt END
	| DEF singleton dot_or_colon fname f_arglist bodystmt END
	| BREAK 
	| NEXT
	| REDO
	| RETRY

  command_asgn: lhs '=' command_rhs
	| var_lhs ASGN command_rhs
	| primary '[' opt_call_args rbracket ASGN command_rhs
	| primary call_op IDENTIFIER ASGN command_rhs
	| primary call_op CONSTANT ASGN command_rhs
	| primary tCOLON2 CONSTANT ASGN command_rhs
	| primary tCOLON2 IDENTIFIER ASGN command_rhs
	| backref ASGN command_rhs

  command_rhs: command_call   =ASGN
	| command_call MOD_RESCUE stmt
	| command_asgn

  command_call: command
#        | blcok_command

  command: fcall command_args =LOWER
	| fcall command_args cmd_brace_block
	| primary call_op operation2 command_args =LOWER
	| primary call_op operation2 command_args cmd_brace_block
	| primary tCOLON2 operation2 command_args	=LOWER
	| primary tCOLON2 operation2 command_args cmd_brace_block
	| SUPER command_args
	| YIELD command_args
	| RETURN call_args
	| BREAK call_args
	| NEXT call_args

  fcall: operation

  command_args: call_args

  method_call: fcall paren_args
	| primary call_op operation2 opt_paren_args
	| primary COLON2 operation2 paren_args
	| primary COLON2 operation3
	| primary call_op paren_args
	| primary COLON2 paren_args
	| SUPER paren_args
	| SUPER
	| primary '[' opt_call_args rbracket

  call_op: '.'
	| ANDDOT

  cmd_brace_block: LBRACE_ARG brace_body '}'

  brace_block: '{' brace_body '}'
	| k_do do_body k_end

  paren_args: '(' opt_call_args rparen

  opt_paren_args:
	| paren_args

  opt_call_args:
	| call_args
	| args ','
	| args ',' assocs ','
	| assocs ','

  call_args: command
	| args opt_block_arg
	| assocs opt_block_arg
	| args ',' assocs opt_block_arg
	| block_arg

  block_arg: AMPER arg

  opt_block_arg: 
	| ',' block_arg


  lhs: user_variable
	| keyword_variable
	| primary '[' opt_call_args rbracket
	| primary call_op IDENTIFIER
	| primary COLON2 IDENTIFIER
	| primary call_op CONSTANT
	| primary COLON2 CONSTANT
	| COLON3 CONSTANT
	| backref

  aref_args: 
	| args trailer
	| args ',' assocs trailer
	| assocs trailer


  var_lhs: user_variable
	| keyword_variable

  assoc_list: none
	| assocs trailer

  assocs: assoc
	| assocs ',' assoc

  assoc : arg tASSOC arg
	| LABEL arg
	| STRING_BEG string_contents tLABEL_END arg
	| DSTAR arg


  opt_terms: ';' lex_beg
      | NL lex_beg

  opt_nl:  
      | NL lex_beg

end

---- header

  require "reish/token"
  require "reish/node"

---- inner

  def initialize(lex)
    @yydebug = nil
    @cmpl_mode = nil
    @input_closed = nil
    @err_token = nil

    @lex = lex
  end

  attr_accessor :yydebug
  attr_accessor :cmpl_mode
  attr_accessor :input_closed
  
  attr_reader :err_token

  def next_token
    @lex.racc_token
  end

  def next_roken_cmpl
    @lex.racc_token_cmpl
  end

    def on_error(token_id, token, value_stack)

      if @yydebug || Reish::debug_cmpl?
	require "pp"
  
	puts "Reish: parse error: token line: #{token.line_no} char: #{token.char_no}"
	puts "TOKEN_ID: #{token_to_str(token_id)}"
	puts "TOKEN: #{token.pretty_inspect}"
	puts "VAULE_STACK: \n#{value_stack.pretty_inspect}"
#      puts "_VAULES: \n#{self.pretty_inspect}"
#      yyerrok
      end
      
      case
      when @cmpl_mode
	@cmpl_mode = value_stack
	Reish::Fail ParserComplSupp
      when @input_closed && token.kind_of?(EOFToken)
	Reish::Fail ParserClosingEOFSupp
#      when @input_closed
#	#Reish::Fail ParserClosingSupp
      else
	@err_token = token
	super
      end
    end

  def yyerror(token, msg)
    raise ParseError, msg
  end
    
# Begin Emacs Environment
# Local Variables:
#   mode: ruby
# End:
