#
#   reish/parser.y - 
#   	Copyright (C) 2014-2017 Keiju ISHITSUKA
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
    nonassoc MOD_IF MOD_UNLESS MOD_WHILE MOD_UNTIL
    right '='
    nonassoc DO LBRACE_I
    nonassoc LBLACK_I 
    left MOD_RESCUE
    left AND_AND OR_OR
#    right '|' BAR_AND COLON2
    right BANG
    left '.' COLON2
    nonassoc HIGHER
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
		result.last_command_to_async
#		result.pipeout = :RESULT
	    } 
	| simple_list1 ';'
	    {
#		result.pipeout = :RESULT
	    } 

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
	| logical_command MOD_IF opt_nl logical_command
	    { 
		result = Node::ModIfCommand(val[0], val[3])
	    }
	| logical_command MOD_UNLESS opt_nl logical_command
	    { 
		result = Node::ModUnlessCommand(val[0], val[3])
	    }
	| logical_command MOD_WHILE opt_nl logical_command
	    { 
		result = Node::ModWhileCommand(val[0], val[3])
	    }
	| logical_command MOD_UNTIL opt_nl logical_command
	    { 
		result = Node::ModUntilCommand(val[0], val[3])
	    }
	| logical_command MOD_RESCUE simple_command_element_list
	    { 
		result = Node::ModRescueCommand(val[0], val[2])
	    }
	| BANG logical_command
            {
		result = Node::BangCommand(val[1])
		result.space_seen = val[0].space_seen
	    }
      	| pipeline_command
	| break_command
	| next_command
	| redo_command
	| retry_command
	| raise_command
	| return_command
	| yield_command
	| assgin_command
	| class_command
        | def_command
	| alias_command

  pipeline_command: pipeline

  pipeline: pipeline '|' opt_nl pipeline_element
	    {
	       result = val[0]
  	       result.pipe_command(:BAR, val[3])
	    }
#	| pipeline COLON2 opt_nl command
#	    {
#	       result = val[0]
#  	       result.pipe_command(:COLON2, val[3])
#	    }
	| pipeline BAR_AND opt_nl pipeline_element
	    {
	       result = val[0]
  	       result.pipe_command(:BAR_AND, val[3])
	    }

#	| pipeline "." opt_nl command
#	    {
#	       result = val[0]
#  	       result.pipe_command(:DOT, val[3])
#	    }
        | pipeline_element

  pipeline_element: command
	    {
		result = Node::PipelineCommand(val[0])
            }
	| strict_pipeline
        | trivial_command

  strict_pipeline: strict_pipeline1
        | strict_pipeline1 '.' opt_nl simple_command
      	    {
	       result = val[0]
  	       result.pipe_command(:DOT, val[3])
	    }
        | strict_pipeline1 COLON2 opt_nl simple_command
	    {
	       result = val[0]
  	       result.pipe_command(:COLON2, val[3])
	    }

  strict_pipeline1: strict_pipeline1 '.' opt_nl strict_command
      	    {
	       result = val[0]
  	       result.pipe_command(:DOT, val[3])
	    }
#	| strict_command COLON2 opt_nl strict_command
#	    {
#	       result = Node::PipelineCommand(val[0])
#  	       result.pipe_command(:COLON2, val[3])
#	    }
	| strict_pipeline1 COLON2 opt_nl strict_command
	    {
	       result = val[0]
  	       result.pipe_command(:COLON2, val[3])
	    }
	| strict_command
	    {
		result = Node::PipelineCommand(val[0])
	    }
	| index_ref_command
	    {
		result = Node::PipelineCommand(val[0])
	    }

  command: simple_command
#	| strict_command
	| shell_command redirection_list
	  {
	        result = Node::Redirector(val[0], val[1])
	  }
#	| function_def

  strict_command: simple_strict_command
	| shell_command

  command_element_list: 
	    {
    		result = Node::CommandElementList.new
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
	| xstring_command
	| trivial_command
	| literal

  simple_command: simple_command_header simple_command_element_list1 opt_do_block 
	    {
#	       result = Node::SimpleCommand(val[0], val[1], val[2])
	       result = val[0]
	       result.set_args val[1]
	       result.block = val[2]
	    }
#	| simple_strict_command

  simple_strict_command: simple_command_header opt_do_block
	    {
#  	       result = Node::SimpleCommand(val[0], Node::CommandElementList.new, val[1])
	       result = val[0]
	       result.set_args Node::CommandElementList.new
	       result.block = val[1]

	    }
	| simple_command_lparen

#   simple_command_lparen: simple_command_lparen_header =LOWER
# 	    {
# 	       result = Node::SimpleCommand(val[0][0], val[0][1])
# 	    }
#         | simple_command_lparen_header do_block
# 	    {
# 	       result = Node::SimpleCommand(val[0][0], val[0][1], val[1])
# 	    }
  simple_command_lparen: simple_command_lparen_header opt_do_block
	    {
#  	       result = Node::SimpleCommand(val[0][0], val[0][1], val[1])
	       result = val[0]
	       result.block = val[1]
	    }

  simple_command_lparen_header:  
	simple_command_lparen_header0
	simple_command_element_list_p indent_pop ")" lex_end 
	    {
#	       result = val[0]
	       result = val[0][0]
	       val[1].lparen = val[0][1]
	       result.set_args val[1]
	    }

  simple_command_lparen_header0: 
	simple_command_header LPARLEN_ARG
	    {
	       @lex.indent_push(val[1])
#      	       result = val[0]
      	       result = val
	    }

  simple_command_element_list_p: opt_nl
  	    {
		@lex.lex_state = Lex::EXPR_ARG
		result = Node::CommandElementList.new
	    }
	| simple_command_element_list_p simple_command_element opt_nl
	    {
		result = val[0]
  		@lex.lex_state = Lex::EXPR_ARG
	        result.push val[1]
	    }
#	| simple_command_element_list_p simple_command_element ',' opt_nl
#	    {
#  		@lex.lex_state = Lex::EXPR_ARG
#	        result.push val[1]
#	    }

  opt_do_block: =LOWER
	    {
		result = nil
	    }
        | do_block

  do_block: do_block_do opt_block_arg compound_list0 indent_pop END
            { 
	      if val[1]
		result = Node::DoBlock(val[2], val[1])
	      else
		result = Node::DoBlock(val[2])
	      end
	    }
	|  do_block_li opt_block_arg compound_list0 indent_pop '}'
            { 
	      if val[1]
		result = Node::DoBlock(val[2], val[1])
	      else
		result = Node::DoBlock(val[2])
	      end
	    }

  do_block_do: DO opt_nl
	    {
	      @lex.indent_push(val[0])
      	    }

  do_block_li: LBRACE_I opt_nl
	    {
	      @lex.indent_push(val[0])
	    }
  opt_block_arg: opt_nl 
	    {
 	      result = nil
 	    }
 	| opt_nl  '|' block_arg '|' opt_nl
 	    {
 	      result = val[2]
	    }

  block_arg: 
    	    {
	       @lex.lex_state = Lex::EXPR_DO_BEG
	       result = []
	    }
	| block_arg opt_nl id
	    {
	      result = val[0]
	      result.push val[2]
	    }

  simple_command_header: id
	    {
      	       result = Node::SimpleCommand(val[0])
	    }
	| PATH
	    {
      	       result = Node::SimpleCommand(val[0])
	    }
	| TEST
	    {
      	       result = Node::SimpleCommand(val[0])
	    }
	| SPECIAL
	    {
      	       result = Node::SimpleCommand(val[0])
	    }
	| CLASS
	    {
      	       result = Node::SimpleCommand(IDToken.dup_from(val[0], "class"))
	    }

  simple_command_element_list: 
	    {
	       result = Node::CommandElementList.new
	    }
	| simple_command_element_list1

  simple_command_element_list1: simple_command_element
	    {
	       result = Node::CommandElementList.new(val[0])
	    }
	| simple_command_element_list1 simple_command_element
	    {
	       result = val[0]
      	       result.push val[1]
	    }

  simple_command_element: command_element_base
	| WILDCARD
	| redirection

  shell_command: literal_command
#	| index_ref_command
	| if_command
	| unless_command
 	| while_command
 	| until_command
        | begin_command
	| case_command
#	| select_command
#	| subshell
#	| arith_command
#	| cond_command
#	| arith_for_command
        | for_command
	| group_command
	| xstring_command

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

  symbol: SYMBEG lex_beg sym
	    {
	      result = Node::Symbol(val[2])
	    }

  sym: id
	| VARIABLE
	| STRING

  assgin_command: assginable '=' opt_nl command_element
	    {
               case val[0].commands.last
	       when Node::SimpleCommand
		  if val[0].commands.last.args.size > 0
		    yyerror val[0], "syntax error not assginable #{val[0].inspect}."
		  end
	       end
	       result = Node::AssginCommand(val[0], val[3])
	    }
#        | index_assgin_command 

#  index_assgin_command: index_ref '=' opt_nl command_element
#            {
#	       result = Node::IndexAssginCommand(val[0][0], val[0][1], val[3])
#	    }

  assginable: strict_pipeline1

  index_ref_command: index_ref
	    {
		result = Node::IndexRefCommand(*val[0])
	    }

  index_ref: referenceable  LBLACK_I opt_nl command_element opt_nl ']'
	    {
		result = [val[0], val[3]]
	    }

  referenceable: strict_pipeline1
#	| literal_command
#	| group_command
#	    {
#	      val[0].pipeout = :RESULT
#	    }
#	| index_ref_command
#	| if_command
#	| unless_command
# 	| while_command
# 	| until_command
#        | begin_command
#	| case_command
#        | for_command
#	| strict_pipeline

  class_command: class_command_class body_list indent_pop END
	    {
		body = Node::BeginCommand(*val[1])
		result = Node::ClassCommand(val[0], nil, body)
	    }		

  class_command_class: CLASS id opt_terms
	    {
		@lex.indent_push(val[0])
		@lex.lex_state = Lex::EXPR_BEG
		result=val[1]
	    }

  def_command:  def_command_def0 body_list indent_pop END
	    {
		body = Node::BeginCommand(*val[1])
		result = Node::DefCommand(val[0], nil, body)
	    }
	|  def_command_def1 body_list indent_pop END
	    {
		arg = val[0][1]
		body = Node::BeginCommand(*val[1])
		result = Node::DefCommand(val[0][0], arg, body)
	    }

  def_command_def0: DEF id lex_beg opt_terms
	    {
		@lex.indent_push(val[0])
		@lex.lex_state = Lex::EXPR_BEG
		result = val[1]
  	    }

  def_command_def1: DEF id lex_beg func_arg_list opt_terms
	    {
		@lex.indent_push(val[0])
		@lex.lex_state = Lex::EXPR_BEG
		result = [val[1], val[3]]
	    } 
	| DEF id lex_beg func_arg_list1 opt_terms
	    {
		@lex.indent_push(val[0])
		@lex.lex_state = Lex::EXPR_BEG
		result = [val[1], val[3]]
	    } 

  func_arg_list: LPARLEN_ARG func_arg_list0 ')'
	    {
	      result = val[1]
	    }

  func_arg_list0: lex_beg 
    	    {
	       result = []
	    }
	| func_arg_list0 opt_nl lex_beg ID
	    {
	      result = val[0]
	      result.push val[3]
	    }

  func_arg_list1: lex_beg ID
    	    {
	       result = [val[1]]
	    }
	| func_arg_list1 lex_beg ID
	    {
	      result = val[0]
	      result.push val[2]
	    }

  alias_command: ALIAS id lex_beg opt_nl id
	    {
     		result = Node::AliasCommand(val[1], val[4])
   	    }

#   alias_command: ALIAS ID lex_beg opt_nl pipeline_command
#   	    {
# 		val[4].pipeout = :NONE
#   		result = Node::AliasCommand(val[1], val[4])
#   	    }



  begin_command: begin_command_begin body_list indent_pop END
	    {
		result = Node::BeginCommand(*val[1])
		result.space_seen = val[0].space_seen
	    }
  begin_command_begin: BEGIN
	    {
		@lex.indent_push(val[0])
		@lex.lex_state = Lex::EXPR_BEG
	    }

  body_list: compound_list opt_rescue opt_else opt_ensure
	    {
		result = val
	    }

  opt_rescue:
	    {
		result = nil
	    }
	| RESCUE command_element_list exc_var then lex_beg compound_list opt_rescue
	    {
		result = Node::RescueCommand(val[1], val[2], val[5])
		if val[6]
		   result, t = val[6], result
		   result = [result] unless result.kind_of?(Array)
		   result.unshift t
		else
		   result = Node::RescueCommand(val[1], val[2], val[5])
		end		  
	    } 
  exc_var: 
	    {
		result = nil
	    }
	| ASSOC lex_beg opt_nl id
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

  while_command: while_command_while cond_pop lex_beg compound_list indent_pop END
	    {
	        result = Node::WhileCommand(val[0], val[3])
	    }
  while_command_while: WHILE cond_push opt_nl logical_command do
	    {
		@lex.indent_push(val[0])
		result = val[3]
	    }

  do: NL
	| ';'
	| ';' DO_COND
        | DO_COND

  until_command: until_command_until cond_pop lex_beg compound_list indent_pop END
	    {
		result = Node::UntilCommand(val[0], val[3])
	    }

  until_command_until: UNTIL cond_push opt_nl logical_command do
	    {
		@lex.indent_push(val[0])
		result = val[3]
	    }
  

  if_command: if_head indent_pop END
	    {
		result = Node::IfCommand(val[0][0], val[0][1])
	    }
	| if_head else_else compound_list indent_pop END
	    {
		result = Node::IfCommand(val[0][0], val[0][1], val[2])
	    }
	| if_head elsif_clause indent_pop END
	    {
		result = Node::IfCommand(val[0][0], val[0][1], val[1])
	    }

  else_else: ELSE opt_terms lex_beg
	    {
		@lex.indent_pop
		@lex.indent_push(val[0])
	    }

  if_head: if_head_if then lex_beg  compound_list 
	    {
		result = [val[0], val[3]]
	    }
  if_head_if: IF opt_nl logical_command
	    {
		@lex.indent_push(val[0])
		result = val[2]
	    } 

  elsif_clause:	elsif_elsif then lex_beg compound_list
	    {
		result = Node::IfCommand(val[0], val[3])
	    }
	| elsif_elsif then lex_beg compound_list else_else compound_list
	    {
		result = Node::IfCommand(val[0], val[3], val[5])
	    }
	| elsif_elsif then lex_beg compound_list elsif_clause
	    {
		result = Node::IfCommand(val[0], val[3], val[4])
	    }

  elsif_elsif: ELSIF opt_nl logical_command
	    {
		@lex.indent_pop
		@lex.indent_push(val[0])
		result = val[2]
	    }

  then: THEN
	| opt_terms
#	| opt_terms THEN

  unless_command: unless_command_unless compound_list opt_else indent_pop END
	    {
		result = Node::IfCommand(val[0], val[2], val[1])
	    }
  unless_command_unless: UNLESS opt_nl logical_command then
	    {
		@lex.indent_push(val[0])
		result = val[2]
	    }

#  for_command: FOR cond_push opt_nl for_arg opt_nl IN lex_arg simple_command_element do {@lex.indent_push(:FOR)} cond_pop lex_beg compound_list indent_pop END
#  for_command: FOR cond_push opt_nl for_arg opt_nl IN lex_arg simple_command_element lex_beg do {@lex.indent_push(:FOR)} cond_pop lex_beg compound_list indent_pop END
  for_command: for_command_for cond_pop lex_beg compound_list indent_pop END
	    {
		result = Node::ForCommand(val[0][0], val[0][1], val[3])
            }
  for_command_for: FOR cond_push opt_nl for_arg opt_nl IN lex_beg
		   logical_command lex_beg do
	    {
		@lex.indent_push(val[0])
		result = [val[3], val[7]]
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

#  case_command: CASE simple_command_element opt_terms {@lex.indent_push(:CASE)} case_body indent_pop END
  case_command: case_command_case  case_body indent_pop END
	    {
		result = Node::CaseCommand(val[0], val[1])
	    }
  case_command_case: CASE logical_command opt_terms
	    {
		@lex.indent_push(val[0])
		result=val[1]
	    }

  case_body: WHEN simple_command_element_list then compound_list cases
# case_body: WHEN logical_command then compound_list cases
# case_body: WHEN when_list then compound_list cases
            {
		case val[4]
		when Array
		  result = val[4]
		  result.unshift Node::WhenCommand(val[1], val[3])
		when nil
		  result = [Node::WhenCommand(val[1], val[3])]
		else
		  result = [Node::WhenCommand(val[1], val[3]), val[4]]
		end
	    }

#        | WHEN simple_command_element_list then compound_list cases

  cases:  opt_else
	| case_body

#   when_list: logical_command
# 	    {
# 	        result = Node::Sequence(val[0])
# 	    }
#         | WORD
# 	    {
# 	        result = Node::Sequence(val[0])
# 	    }
# 	| WILDCARD
# 	    {
# 	        result = Node::Sequence(val[0])
# 	    }
#         | when_list "," lex_beg logical_command
# 	    {
# 		val[0].add_command(val[3])
# 		result = val[0]
# 	    }

  break_command: BREAK simple_command_element_list
	    {
		result = Node::BreakCommand(val[1])
	    }

  next_command: NEXT simple_command_element_list
	    {
		result = Node::NextCommand(val[1])
	    }

  redo_command: REDO
	    {
		result = Node::RedoCommand()
	    }

  retry_command: Retry
	    {
		result = Node::RetryCommand()
	    }

  raise_command: RAISE simple_command_element_list
	    {
		result = Node::RaiseCommand(val[1])
	    }

  return_command: RETURN simple_command_element_list
	    {
		result = Node::ReturnCommand(val[1])
	    }

  yield_command: YIELD simple_command_element_list
	    {
		result = Node::YieldCommand(val[1])
	    }

  group_command: group_command_group compound_list indent_pop ')' lex_arg
#  group_command: '(' {@lex.indent_push(:LPAREN_G)} compound_list indent_pop ')' lex_arg
	    {
	        result = Node::Group(val[1])
	    }

  group_command_group: '('
	    {
		@lex.indent_push(val[0])
		@lex.lex_state = Lex::EXPR_BEG
	    }

  xstring_command: xstring_command_xstring  compound_list XSTRING_END indent_pop lex_arg
	    {
	        result = Node::XString(val[1])
	    }

  xstring_command_xstring: XSTRING_BEG
	    {
		@lex.indent_push(val[0])
		@lex.lex_state = Lex::EXPR_BEG
	    }

#   trivial_command: trivial_command0 lex_arg

#   trivial_command0: '$' simple_command_header =LOWER
# 	    {         
# 	       result = Node::SimpleCommand(val[1], Node::CommandElementList.new)
# 	       result.pipeout = :RESULT
# 	    }
# 	| '$' simple_command_header do_block
# 	    {         
# 	       result = Node::SimpleCommand(val[1], Node::CommandElementList.new, val[2])
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


  trivial_command: "$" lex_beg trivial_command0 lex_arg
	    {
		result = val[2]
	    }

  trivial_command0: strict_pipeline1
 	    {         
 	       result.pipeout = :RESULT
 	    }

#   trivial_command0: simple_command_header opt_do_block
# 	    {         
# 	       result = Node::SimpleCommand(val[0], [], val[1])
# 	       result.pipeout = :RESULT
# 	    }
# 	| simple_command_lparen
# 	    {         
# 	       result = val[0]
# 	       result.pipeout = :RESULT
# 	    }
# #	| test_command_lparen
# #	    {         
# #	       result = val[0]
# #	       result.pipeout = :RESULT
# #	    }
# 	| index_ref_command
# 	    {         
# 	       result = val[0]
# 	    }
# 	| assgin_command
# 	    {         
# 	       result = val[0]
# 	    }
# 	| PSEUDOVARIABLE
# 	    {         
# 	       result = val[0]
# 	    }

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

  array: array_array array_element_list indent_pop ']'
	    {
		result = Node::Array(val[1])
	    }

  array_array: LBLACK_A
	    {
  		@lex.indent_push(val[0])
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

  hash: hash_hash hash_element_list indent_pop '}'
	    {
		result = Node::Hash(val[1])
	    }
  hash_hash: LBRACE_H
	    {
		@lex.indent_push(val[0])
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
	| opt_nl compound_list1 NL lex_beg opt_nl
	    {
		result = val[1]
	    } 
	| opt_nl compound_list1 '&' lex_beg  opt_nl
	    {
		val[1].last_command_to_async
		result = val[1]
	    } 
	| opt_nl compound_list1 ';'  lex_beg opt_nl
	    {
		result = val[1]
	    } 

   compound_list0: 
 	    {
 		result = Node::Sequence()
 	    }
         | compound_list1 
 	    {
 		result = val[0]
 	    }
 	| compound_list1 NL lex_beg opt_nl
 	    {
 		result = val[0]
 	    } 
 	| compound_list1 '&' lex_beg  opt_nl
 	    {
 		val[1].last_command_to_async
 		result = val[0]
 	    } 
 	| compound_list1 ';'  lex_beg opt_nl
 	    {
 		result = val[0]
	    } 

  compound_list1: logical_command
	    {
	        result = Node::Sequence(val[0]) 
	    }
	| compound_list1 NL lex_beg opt_nl logical_command
	    { 
		val[0].add_command(val[4])
		result = val[0]
	    }
	| compound_list1 "&" lex_beg opt_nl logical_command
	    { 
		val[0].last_command_to_async
		val[0].add_command(val[4])
		result = val[0]
	    }
  	| compound_list1 ";" lex_beg opt_nl logical_command 
	    { 
		val[0].add_command(val[4])
		result = val[0]
	    }

  redirection_list: redirection
          {
	    result = [val[0]]
          }
	| redirection_list redirection
	  {
	    val[0].push val[1]
	    result = val[0]
	  }

  redirection:	'>' redirection_element
	  {
	    result = Node::Redirection(-1, ">", val[1])
	    result.space_seen = val[0].space_seen
	  }
	| '<' redirection_element
	  {
	    result = Node::Redirection(-1, "<", val[1])
	    result.space_seen = val[0].space_seen
	  }
	| FID '>' redirection_element
	  {
	    result = Node::Redirection(val[0], ">", val[2])
	    result.space_seen = val[0].space_seen
	  }
	| FID '<' redirection_element
	  {
	    result = Node::Redirection(val[0], "<", val[2])
	    result.space_seen = val[0].space_seen
	  }
	| REDIR_WORD '>' redirection_element
	| REDIR_WORD '<' redirection_element
	| GREATER_GREATER redirection_element
	  {
	    result = Node::Redirection(-1, ">>", val[1])
	    result.space_seen = val[0].space_seen
	  }
	| FID GREATER_GREATER redirection_element
	  {
	    result = Node::Redirection(val[0], ">>", val[2])
	    result.space_seen = val[0].space_seen
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
	    result.space_seen = val[0].space_seen
	  }
	| AND_GREATER_GREATER redirection_element
	  {
	    result = Node::Redirection(-1, "&>>", val[1])
	    result.space_seen = val[0].space_seen
	  }

  redirection_element: command_element_base
	| WILDCARD

  id: ID
	| ID2

  simple_list_terminator:	NL
	| EOF

  opt_nl_arg: lex_arg
      | lex_arg NL 

  opt_terms: ';' lex_beg
      | NL lex_beg

  opt_nl:  
      | NL lex_beg
	
  cond_push: {@lex.cond_push(true)}
  cond_pop: {@lex.cond_pop}

  lex_beg: {@lex.lex_state = Lex::EXPR_BEG}
  lex_arg: {@lex.lex_state = Lex::EXPR_ARG}
  lex_end: {@lex.lex_state = Lex::EXPR_END}

  indent_pop: {@lex.indent_pop}  

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
