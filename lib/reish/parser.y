#
#   reish/parser.y - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

class Reish::Parser

  preclow
#    left '&' ';' '\n' EOF
    nonassoc  LOWER
    nonassoc DO LBRACE_I
    left AND_AND OR_OR
#    right '|' BAR_AND COLON2
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
	| simple_list1 '&'
	    {
		val[0].last_command_to_async
		result = val[0]
	    } 
	| simple_list1 ';'

  simple_list1:	logical_command
	    {
		result = Node::Sequence(val[0])
            }
	| simple_list1 "&" logical_command
	    { 
		val[0].last_command_to_async
		val[0].add_command(val[2])
		result = val[0]
	    }
  	| simple_list1 ";" logical_command 
	    { 
		val[0].add_command(val[2])
		result = val[0]
	    }

  logical_command: logical_command AND_AND opt_nl logical_command
	    { 
		result = Node::LogicalCommandAA(val[0], val[3])
	    }
	| logical_command OR_OR opt_nl logical_command
	    { 
		result = Node::LogicalCommandOO(val[0], val[3])
	    }
      	| pipeline_command

  pipeline_command: pipeline
	| BANG pipeline

  pipeline: pipeline '|' opt_nl command
	    {
	       result = val[0]
  	       result.pipe_command(:BAR, val[3])
	    }
	| pipeline COLON2 opt_nl command
	    {
	       result = val[0]
  	       result.pipe_command(:COLON2, val[3])
	    }
	| pipeline BAR_AND opt_nl command
	    {
	       result = val[0]
  	       result.pipe_command(:BAR_AND, val[3])
	    }

	| pipeline "." opt_nl command
	    {
	       result = val[0]
  	       result.pipe_command(:DOT, val[3])
	    }
        | command
	    {
		result = Node::PipelineCommand(val[0])
            }
	
  command: simple_command
	| shell_command
	| shell_command redirection_list
#	| function_def

  command_element_list: 
	    {
		result = []
	    } 
	| command_element_list command_element
	    {
		result.push val[1]
	    }

  command_element: command_element_base
# for l=*
	| WILDCARD
	    {
	        yyerror val[0], "syntax error: wildcasd #{val[0].inspect} can't use this place."
	    }

  command_element_base: WORD
	| group_command
	| trivial_command
	| literal

  simple_command: simple_command_header simple_command_element_list 
	    {         
	       result = Node::SimpleCommand(val[0], val[1])
	    }
	| simple_command_header simple_command_element_list do_block
	    {
	       result = Node::SimpleCommand(val[0], val[1], val[2])
	    }
	| simple_command_lparen

  simple_command_lparen: simple_command_header LPARLEN_ARG
			 simple_command_element_list_p ")" lex_end =LOWER

	    {
	       result = Node::SimpleCommand(val[0], val[2])
	    }
	| simple_command_header LPARLEN_ARG simple_command_element_list_p ")" lex_end do_block
	    {
	       result = Node::SimpleCommand(val[0], val[2], val[5])
	    }

  simple_command_element_list_p: opt_nl
  	    {
		@lex.lex_state = Lex::EXPR_ARG
		result = []
	    }
	| simple_command_element_list_p simple_command_element opt_nl
	    {
  		@lex.lex_state = Lex::EXPR_ARG
	        result.push val[1]
	    }
#	| simple_command_element_list_p simple_command_element ',' opt_nl
#	    {
#  		@lex.lex_state = Lex::EXPR_ARG
#	        result.push val[1]
#	    }

  do_block: DO opt_block_arg compound_list END
            { 
	      if val[1]
		result = Node::DoBlock(val[2], val[1])
	      else
		result = Node::DoBlock(val[2])
	      end
	    }
	| LBRACE_I opt_block_arg compound_list '}'
            { 
	      if val[1]
		result = Node::DoBlock(val[2], val[1])
	      else
		result = Node::DoBlock(val[2])
	      end
	    }

  opt_block_arg: 
	    {
	      result = nil
	    }
	| '|' block_arg '|'
	    {
	      result = val[1]
	    }

  block_arg: 
    	    {
	       @lex.lex_state = Lex::EXPR_DO_BEG
	       result = []
	    }
	| block_arg opt_nl ID
	    {
	      result = val[0]
	      result.push val[2]
	    }

  simple_command_header: ID
	| PATH
	| TEST
	| SPECIAL

  simple_command_element_list: 
	    {
	       result = []
	    }
	| simple_command_element_list simple_command_element
	    {
	       result.push val[1]
	    }
  simple_command_element: command_element_base
	| WILDCARD
	| redirection

  shell_command: literal_command
	| assgin_command
	| index_ref_command
	| if_command
 	| while_command
        | begin_command
#	| case_command
#	| UNTIL compound_list DO compound_list DONE
#	| select_command
#	| subshell
#	| arith_command
#	| cond_command
#	| arith_for_command
        | for_command
	| group_command
#	| test_command

  literal_command: literal
	    {
	      result = Node::LiteralCommand(val[0])  
    	    }

  literal: STRING
	| REGEXP
	| NUMBER
	| INTEGER
        | VARIABLE
	| PSEUDOVARIABLE
	| array
	| hash
	| symbol
	| ruby_exp

  symbol: SYMBEG sym
	    {
	      result = Node::Symbol(val[1])
	    }

  sym: ID
	| VARIABLE
	| STRING

  assgin_command: ID '=' command_element
	    {
	       result = Node::AssginCommand(val[0], val[2])
	    }
	| index_assgin_command

  index_assgin_command: index_ref '=' opt_nl command_element
            {
	       result = Node::IndexAssginCommand(val[0][0], val[0][1], val[3])
	    }

  index_ref_command: index_ref
	    {
		result = Node::IndexRefCommand(*val[0])
	    }

  index_ref: referenceable LBLACK_I  opt_nl command_element opt_nl ']'
	    {
		result = [val[0], val[3]]
	    }

referenceable: ID
#	| trivial_command
	| literal
	| group_command
	    {
	      val[0].pipeout = :RESULT
	    }
	| index_ref_command

  begin_command: BEGIN body_list END
	    {
		result = Node::BeginCommand(*val[1])
	    }

  body_list: compound_list opt_rescue opt_else opt_ensure
	    {
		result = val
	    }

  opt_rescue:
	    {
		result = nil
	    }
	| RESCUE command_element_list exc_var then compound_list opt_rescue
	    {
		result = Node::RescueCommand(val[1], val[2], val[4])
		result = [result, val[5]] if val[5]
		result
	    } 
  exc_var: 
	    {
		result = nil
	    }
	| ASSOC lex_beg opt_nl ID
	    {
		result = val[3]
	    }
  opt_else: 
	    {
		result = nil
	    }

	| ELSE compound_list
	    {
		result = val[1]
	    }
  opt_ensure: 
	    {
		result = nil
	    }
	| ENSURE compound_list
	    {
		result = val[1]
	    }

  while_command: WHILE cond_push opt_nl logical_command do cond_pop compound_list END
	    {
	       result = Node::WhileCommand(val[3], val[6])
	    }

  do: NL
	| ';'
	| DO_COND

  if_command: IF opt_nl logical_command then compound_list END
	    {
		result = Node::IfCommand(val[2], val[4])
	    }
	|	IF opt_nl logical_command then compound_list ELSE compound_list END
	    {
		result = Node::IfCommand(val[2], val[4], val[6])
	    }
	|	IF opt_nl logical_command then compound_list elsif_clause END
	    {
		result = Node::IfCommand(val[2], val[4], val[5])
	    }

  elsif_clause:	ELSIF opt_nl logical_command then compound_list
	    {
		result = Node::IfCommand(val[2], val[4])
	    }
	|	ELSIF opt_nl logical_coomand then compound_list ELSE compound_list
	    {
		result = Node::IfCommand(val[2], val[4], val[6])
	    }
	|	ELSIF opt_nl logical_command then compound_list elif_clause
	    {
		result = Node::IfCommand(val[2], val[4], val[6])
	    }

  then: NL
	| ';'
	| THEN

  for_command: FOR opt_nl for_arg opt_nl IN cond_push
	       logical_command do cond_pop compound_list END
	    {
		result = Node::ForCommand(val[2], val[6], val[9])
            }

  for_arg: ID
    	    {
	       @lex.lex_state = Lex::EXPR_BEG
	       result = [val[0]]
	    }
	| for_arg opt_nl ID
	    {
	      result = val[0]
	      result.push val[2]
	    }


  group_command: '(' compound_list ')' lex_arg
	    {
	        result = Node::Group(val[1])
	    }
#   trivial_command: trivial_command0 lex_arg

#   trivial_command0: '$' simple_command_header =LOWER
# 	    {         
# 	       result = Node::SimpleCommand(val[1], [])
# 	       result.pipeout = :RESULT
# 	    }
# 	| '$' simple_command_header do_block
# 	    {         
# 	       result = Node::SimpleCommand(val[1], [], val[2])
# 	       result.pipeout = :RESULT
# 	    }
# 	| '$' simple_command_lparen
# 	    {         
# 	       result = val[1]
# 	       result.pipeout = :RESULT
# 	    }
# #	| '$' test_command_lparen
# #	    {         
# #	       result = val[1]
# #	       result.pipeout = :RESULT
# #	    }
# 	| '$' index_ref_command
# 	    {         
# 	       result = val[1]
# 	    }
# 	| '$' assgin_command
# 	    {         
# 	       result = val[1]
# 	    }
# 	| '$' PSEUDOVARIABLE
# 	    {         
# 	       result = val[1]
# 	    }


  trivial_command: '$' lex_beg trivial_command0 lex_arg
	    {
		result = val[2]
	    }

  trivial_command0: simple_command_header =LOWER
	    {         
	       result = Node::SimpleCommand(val[0], [])
	       result.pipeout = :RESULT
	    }
	| simple_command_header do_block
	    {         
	       result = Node::SimpleCommand(val[0], [], val[1])
	       result.pipeout = :RESULT
	    }
	| simple_command_lparen
	    {         
	       result = val[0]
	       result.pipeout = :RESULT
	    }
#	| test_command_lparen
#	    {         
#	       result = val[0]
#	       result.pipeout = :RESULT
#	    }
	| index_ref_command
	    {         
	       result = val[0]
	    }
	| assgin_command
	    {         
	       result = val[0]
	    }
	| PSEUDOVARIABLE
	    {         
	       result = val[0]
	    }

#  test_command: TEST simple_command_element_list 
#	    {         
#	       result = Node::TestCommand(val[0], val[1])
#	    }
#	| TEST simple_command_element_list do_block
#	    {
#	       result = Node::TestCommand(val[0], val[1], val[2])
#	    }
#	| test_command_lparen

#  test_command_lparen: TEST LPARLEN_ARG simple_command_element_list_p ")" lex_end =LOWER
#	    {
#	       result = Node::TestCommand(val[0], val[2])
#	    }
#	| TEST LPARLEN_ARG simple_command_element_list_p ")" lex_end do_block
#	    {
#	       result = Node::TestCommand(val[0], val[2], val[5])
#	    }


  ruby_exp: RUBYEXP
	    {
		result = Node::RubyExp(val[0])
	    }

  array: LBLACK_A array_element_list ']'
	    {
		result = Node::Array(val[1])
	    }	  

  array_element_list: opt_nl
  	    {
		@lex.lex_state = Lex::EXPR_ARG
		result = []
	    }
	| array_element_list command_element opt_nl
	    {
  		@lex.lex_state = Lex::EXPR_ARG
	        result.push val[1]
	    }
	| array_element_list command_element ',' opt_nl
	    {
  		@lex.lex_state = Lex::EXPR_ARG
	        result.push val[1]
	    }

  hash: LBRACE_H hash_element_list '}'
	    {
		result = Node::Hash(val[1])
	    }	  

  hash_element_list: opt_nl
	    {
		@lex.lex_state = Lex::EXPR_ARG
	        result = []
	    } 
	| hash_element_list hash_assoc
	    {
	        @lex.lex_state = Lex::EXPR_ARG
	        result.push val[1]
	    }
  hash_assoc: command_element opt_nl ASSOC NL lex_arg command_element opt_nl
	    {
	        @lex.lex_state = Lex::EXPR_ARG
		result = [val[0], val[5]]
	    }
	| command_element opt_nl ASSOC command_element opt_nl
	    {
	        @lex.lex_state = Lex::EXPR_ARG
		result = [val[0], val[3]]
	    }

  compound_list: opt_nl
	    {
		result = Node::Sequence()
	    }
        | opt_nl compound_list1 
	    {
		result = val[1]
	    }
	| opt_nl compound_list1 NL opt_nl
	    {
		result = val[1]
	    } 
	| opt_nl compound_list1 '&' opt_nl
	    {
		val[1].last_command_to_async
		result = val[1]
	    } 
	| opt_nl compound_list1 ';' opt_nl
	    {
		result = val[1]
	    } 

  compound_list1: logical_command
	    {
	        result = Node::Sequence(val[0]) 
	    }
	| compound_list1 NL opt_nl logical_command
	    { 
		val[0].add_command(val[3])
		result = val[0]
	    }
	| compound_list1 "&" opt_nl logical_command
	    { 
		val[0].last_command_to_async
		val[0].add_command(val[3])
		result = val[0]
	    }
  	| compound_list1 ";" opt_nl logical_command 
	    { 
		val[0].add_command(val[3])
		result = val[0]
	    }

#redirection_list: redirection
#	| redirection_list redirection

  redirection:	'>' redirection_element
	  {
	    result = Node::Redirection(-1, ">", val[1])
	  }
	| '<' redirection_element
	  {
	    result = Node::Redirection(-1, "<", val[1])
	  }
	| FID '>' redirection_element
	  {
	    result = Node::Redirection(val[0], ">", val[2])
	  }
	| FID '<' redirection_element
	  {
	    result = Node::Redirection(val[0], "<", val[2])
	  }
	| REDIR_WORD '>' redirection_element
	| REDIR_WORD '<' redirection_element
	| GREATER_GREATER redirection_element
	  {
	    result = Node::Redirection(-1, ">>", val[1])
	  }
	| FID GREATER_GREATER redirection_element
	  {
	    result = Node::Redirection(val[0], ">>", val[2])
	  }
	| REDIR_WORD GREATER_GREATER redirection_element
	| GREATER_BAR redirection_element
	| FID GREATER_BAR redirection_element
	| REDIR_WORD GREATER_BAR redirection_element
	| LESS_GREATER redirection_element
	| FID LESS_GREATER redirection_element
	| REDIR_WORD LESS_GREATER redirection_element
	| LESS_LESS redirection_element
	| FID LESS_LESS redirection_element
	| REDIR_WORD LESS_LESS redirection_element
	| LESS_LESS_MINUS redirection_element
	| FID LESS_LESS_MINUS redirection_element
	| REDIR_WORD  LESS_LESS_MINUS redirection_element
	| LESS_LESS_LESS redirection_element
	| FID LESS_LESS_LESS redirection_element
	| REDIR_WORD LESS_LESS_LESS redirection_element
#	| LESS_AND INTEGER
#	| FID LESS_AND INTEGER
#	| REDIR_WORD LESS_AND INTEGER
#	| GREATER_AND INTEGER
#	| FID GREATER_AND INTEGER
#	| REDIR_WORD GREATER_AND INTEGER
	| LESS_AND redirection_element
	| FID LESS_AND redirection_element
	| REDIR_WORD LESS_AND redirection_element
	| GREATER_AND redirection_element
	| FID GREATER_AND redirection_element
	| REDIR_WORD GREATER_AND redirection_element
	| GREATER_AND '-'
	| FID GREATER_AND '-'
	| REDIR_WORD GREATER_AND '-'
	| LESS_AND '-'
	| FID  LESS_AND '-'
	| REDIR_WORD LESS_AND '-'
	| AND_GREATER redirection_element
	  {
	    result = Node::Redirection(-1, "&>", val[1])
	  }
	| AND_GREATER_GREATER redirection_element
	  {
	    result = Node::Redirection(-1, "&>>", val[1])
	  }

  redirection_element: command_element_base
	| WILDCARD


  simple_list_terminator:	NL
	| EOF

  opt_nl_arg: lex_arg
      | lex_arg NL 

  opt_nl:  
      | NL
	

  nl_beg: NL 

  cond_push: {@lex.cond_push(true)}
  cond_pop: {@lex.cond_pop}

  lex_beg: {@lex.lex_state = Lex::EXPR_BEG}
  lex_arg: {@lex.lex_state = Lex::EXPR_ARG}
  lex_end: {@lex.lex_state = Lex::EXPR_END}

end

---- header

  require "reish/token"
  require "reish/node"

---- inner

  def initialize(lex)
    @yydebug = true

    @lex = lex
  end

  attr_accessor :yydebug

  def next_token
    @lex.racc_token
  end

#   def on_error(token_id, token, value_stack)
    
#     puts "Reish: parse error: token line: #{token.line_no} char: #{token.char_no}"
#     p value_stack
#     raise

#   end

  def yyerror(token, msg)
    raise ParseError, msg
  end
    
# Begin Emacs Environment
# Local Variables:
#   mode: ruby
# End:
