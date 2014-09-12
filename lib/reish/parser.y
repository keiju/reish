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
    left '&' ';' '\n' EOF
    left AND_AND OR_OR
    right '|' BAR_AND
  prechigh

  rule
  inputunit: simple_list simple_list_terminator
	    {
		_values.push Node::InputUnit(val[0], val[1])
	        yyaccept
	    }
	| '\n'
	    {
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
		result = Node::SeqCommand(val[0])
#	        result = val[0]
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

  logical_command: logical_command AND_AND newline_list logical_command
	    { 
		result = Node::ConnectCommandAA(val[0], val[3])
	    }
	| logical_command OR_OR newline_list logical_command
	    { 
		result = Node::ConnectCommandOO(val[0], val[3])
	    }
      	| pipeline_command

#   simple_list1:	simple_list1 AND_AND newline_list simple_list1
# 	    { 
# 		result = Node::ConnectCommandAA(val[0], val[3])
# 	    }
# 	| simple_list1 OR_OR newline_list simple_list1
# 	    { 
# 		result = Node::ConnectCommandOO(val[0], val[3])
# 	    }
# 	| simple_list1 '&'  simple_list1
# 	    { 
# 		#
# 		result = Node::ConnectCommandANP(val[0], val[2])
# 	    }
# 	| simple_list1 ';'  simple_list1
# 	    { 
# 		result = Node::ConnectCommandSEQ(val[0], val[2])
# 	    }
#       	| pipeline_command

  pipeline_command: pipeline
	| BANG pipeline

  pipeline: pipeline '|' newline_list pipeline
	    {
  		result = Node::ConnectCommandPP(val[0], val[3])
	    }
	| pipeline BAR_AND newline_list pipeline
	    {
		result = Node::ConnectCommandPP(val[0], val[3])
	    }
	| command

  command: simple_command
	| shell_command
	| shell_command redirection_list
#	| function_def

  simple_command: simple_command_header simple_command_element_list 
	    {         
	      result = Node::SimpleCommand(val[0], val[1])
	    }
	| simple_command_header simple_command_element_list DO compound_list END
            { 
	      result = Node::SimpleCommand(val[0], val[1], val[3])
	    }
	| simple_command_header simple_command_element_list '{'	compound_list '}'
            { 
	      result = Node::SimpleCommand(val[0], val[1], val[3])
	    }
    
  simple_command_element_list: 
	    {
	       result = []
	    }
	| simple_command_element_list simple_command_element
	    {
	       result.push val[1]
	    }
  simple_command_header: ID

  simple_command_element: WORD
#	| ASSIGNMENT_WORD
#	| ID
	| redirection
	| group_command
	| ruby_exp_command

  shell_command: FOR_COMMAND
	| if_command
 	| while_command
#	| case_command
#	| UNTIL compound_list DO compound_list DONE
#	| select_command
#	| subshell
#	| arith_command
#	| cond_command
#	| arith_for_command
	| group_command
	| ruby_exp_command

  while_command: WHILE {@lex.cond_push(true)} newline_list logical_command do {@lex.cond_pop} compound_list END
	    {
	       result = Node::WhileCommand(val[3], val[6])
	    }

  do: '\n' newline_list
	| ';' newline_list
	| COND_DO

  if_command: IF newline_list logical_command then compound_list END
	    {
		result = Node::IfCommand(val[2], val[4])
	    }
	|	IF newline_list logical_command then compound_list ELSE compound_list END
	    {
		result = Node::IfCommand(val[2], val[4], val[6])
	    }
	|	IF newline_list logical_command then compound_list elsif_clause END
	    {
		result = Node::IfCommand(val[2], val[4], val[5])
	    }

  elsif_clause:	ELSIF newline_list logical_command then compound_list
	    {
		result = Node::IfCommand(val[2], val[4])
	    }
	|	ELSIF newline_list logical_coomand then compound_list ELSE compound_list
	    {
		result = Node::IfCommand(val[2], val[4], val[6])
	    }
	|	ELSIF newline_list logical_command then compound_list elif_clause
	    {
		result = Node::IfCommand(val[2], val[4], val[6])
	    }

  then: '\n' newline_list
	| ';'
	| THEN

  group_command: '(' compound_list ')'
	    {
	      result = Node::Group(val[1])
	    }
  ruby_exp_command: RUBYEXP
	    {
		result = Node::RubyExp(val[0])
	    }

  compound_list: newline_list
	    {
		result = Node::SeqCommand()
	    }
        | newline_list compound_list1 
	    {
		result = val[1]
	    }
	| newline_list compound_list1 '\n' newline_list
	    {
		result = val[1]
	    } 
	| newline_list compound_list1 '&' newline_list
	    {
		val[1].last_command_to_async
		result = val[1]
	    } 
	| newline_list compound_list1 ';' newline_list
	    {
		result = val[1]
	    } 

  compound_list1: logical_command
	    {
	        result = Node::SeqCommand(val[0]) 
	    }
	| compound_list1 "\n" newline_list logical_command
	    { 
		val[0].add_command(val[3])
		result = val[0]
	    }
	| compound_list1 "&" newline_list logical_command
	    { 
		val[0].last_command_to_async
		val[0].add_command(val[3])
		result = val[0]
	    }
  	| compound_list1 ";" newline_list logical_command 
	    { 
		val[0].add_command(val[3])
		result = val[0]
	    }

#redirection_list: redirection
#	| redirection_list redirection

  redirection:	'>' WORD
	  {
	    result = Node::Redirection(1, ">", val[1])
	  }
	| '<' WORD
	  {
	    result = Node::Redirection(0, "<", val[1])
	  }
	| NUMBER '>' WORD
	  {
	    result = Node::Redirection(val[0], ">", val[3])
	  }
	| NUMBER '<' WORD
	  {
	    result = Node::Redirection(val[0], "<", val[3])
	  }
	| REDIR_WORD '>' WORD
	| REDIR_WORD '<' WORD
	| GREATER_GREATER WORD
	| NUMBER GREATER_GREATER WORD
	| REDIR_WORD GREATER_GREATER WORD
	| GREATER_BAR WORD
	| NUMBER GREATER_BAR WORD
	| REDIR_WORD GREATER_BAR WORD
	| LESS_GREATER WORD
	| NUMBER LESS_GREATER WORD
	| REDIR_WORD LESS_GREATER WORD
	| LESS_LESS WORD
	| NUMBER LESS_LESS WORD
	| REDIR_WORD LESS_LESS WORD
	| LESS_LESS_MINUS WORD
	| NUMBER LESS_LESS_MINUS WORD
	| REDIR_WORD  LESS_LESS_MINUS WORD
	| LESS_LESS_LESS WORD
	| NUMBER LESS_LESS_LESS WORD
	| REDIR_WORD LESS_LESS_LESS WORD
	| LESS_AND NUMBER
	| NUMBER LESS_AND NUMBER
	| REDIR_WORD LESS_AND NUMBER
	| GREATER_AND NUMBER
	| NUMBER GREATER_AND NUMBER
	| REDIR_WORD GREATER_AND NUMBER
	| LESS_AND WORD
	| NUMBER LESS_AND WORD
	| REDIR_WORD LESS_AND WORD
	| GREATER_AND WORD
	| NUMBER GREATER_AND WORD
	| REDIR_WORD GREATER_AND WORD
	| GREATER_AND '-'
	| NUMBER GREATER_AND '-'
	| REDIR_WORD GREATER_AND '-'
	| LESS_AND '-'
	| NUMBER LESS_AND '-'
	| REDIR_WORD LESS_AND '-'
	| AND_GREATER WORD
	| AND_GREATER_GREATER WORD

simple_list_terminator:	'\n'
	| EOF

newline_list:
	| newline_list '\n'

end

---- header

  require "reish/token"
  require "reish/node"

---- inner

  def initialize(lex)
    @yydebug = true

    @lex = lex
  end

  def next_token
    @lex.racc_token
  end
