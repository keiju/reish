#
#   completion.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
require "pp"

require "reish/path-finder"
require "reish/cmpl/compspec"
require "reish/cmpl/comp-command"
require "reish/cmpl/comp-cmd-proc"

module Reish

  class Completor

    def initialize(shell)
      @shell = shell

      @lex = Lex.new
      @parser = Parser.new(@lex)

      @parser.cmpl_mode = true
      @parser.yydebug = Reish::debug_cmpl_yy?

      case shell.io
      when ReadlineInputMethod
	@completion_proc = proc{|input|
	  puts "input: #{input}" if @debug
	  expr = @shell.lex.readed + Readline.line_buffer
	  puts "input all: #{expr}" if @debug

	  cands = candidate(expr)
	  case cands
	  when nil
	    nil
	  when Array
	    cands
	  when String
	    [cands, cands]
	  else
	    cands.for_readline
	  end
	}

	Readline.completion_proc = @completion_proc
      when ReidlineInputMethod, ReidlineInputMethod2
	@completion_proc = proc{|expr|
	  cand = candidate(expr)
	  if @lex.space_seen
	    [cand, ""]
	  else
	    token = @lex.pretoken
	    case token
	    when ValueToken
	      s = token.value
	    when ReservedWordToken, SimpleToken
	      s = token.token_id
	    else
	      s = ""
	    end
	    [cand, s]
	  end
	}
	shell.io.set_cmpl_proc &@completion_proc
      end
    end

    attr_reader :completion_proc

    def candidate(str)
      if str == ""
	puts "input: ''" if Reish::debug_cmpl?
	return candidate_commands 
      end

      im = StringInputMethod.new(nil, str)

      @lex.initialize_input
      @lex.set_input(im) do
	if l = im.gets
	  print l  if Reish::debug_cmpl?
	else
	  print "\n" if Reish::debug_cmpl?
	end
	l
      end

      parsed = nil
      begin 
	input_unit = [@parser.yyparse(@lex, :racc_token_cmpl)]
	puts "PARSE COMPLETED"  if Reish::debug_cmpl?

	parsed = true

      rescue ParserComplSupp
	if Reish::debug_cmpl?
	  puts "PARSE IMCOMLETED" 
	  require "pp"
	  puts "TEST_CMPL:"
	  pp @parser.cmpl_mode
	end
	  
	parsed = false
	input_unit = @parser.cmpl_mode

	puts "INDENT CURRENT: #{@lex.indent_current.inspect}" if Reish::debug_cmpl?
      end

      if Reish::debug_cmpl?
	puts "INPUT UNIT:"
	pp input_unit
	puts "SPACE_SEEN: #{@lex.space_seen}"
	puts "LAST_TOKEN:"
	pp @lex.pretoken
	puts "LEX_STATE:"
	pp @lex.lex_state_sym
      end

#      if @lex.lex_state?(Lex::EXPR_ARG) && @lex.pretoken === ID && !@lex.space_seen
#	# ls
#      elsif 

      path = find_path(input_unit, @lex.pretoken)
      if Reish::debug_cmpl?
	puts "PATH:"
	pp path
	puts "PATH: END"
      end

      if @lex.space_seen
	if @lex.lex_state?(Lex::EXPR_BEG | Lex::EXPR_DO_BEG)
	  puts "IDENT CMPL: BEG/SP" if Reish::debug_cmpl?
	  puts "CANDIDATE: ANY COMMAND" if Reish::debug_cmpl?

	  command = find_argumentable_element_in_path(@lex.pretoken, path, input_unit)
	  puts "CANDIDATE: ANY COMMAND OF: #{command.inspect}" if Reish::debug_cmpl?

	  candidate_commands(command)

	elsif @lex.lex_state?(Lex::EXPR_ARG | Lex::EXPR_END)
	  puts "IDENT CMPL: ARG/END" if Reish::debug_cmpl?
	  
	  command = find_argumentable_element_in_path(@lex.pretoken, path, input_unit)

	  puts "CANDINATE: ARGUMENT OF: #{command.inspect}" if Reish::debug_cmpl?
	  
	  candidate_argument_of(command)


	else
	  # ここは来ない?
	  # EXPR_MID | EXPR_ARG | EXPR_FNAME | 
	  #   EXPR_DOT | EXPR_CLASS | EXPR_EQ_ARG

	  puts "CANDINATE: ARGUMENT OF: UNKNOWN"
	  puts "LEX STATE: #{@lex.state_sym}"
	end
      else
	case @lex.pretoken
	when SimpleToken, ReservedWordToken
	  case @lex.pretoken.token_id
	  when :NL, '\\', :ASSOC, :XSTRING_END, :XSTRING_BEG,
	      "(", :LBLACK_A, :LBLACK_I, :LBRACE_H, :LBRACE_I,
	      "]", ")", "}", ":", :DOT_COMMAND, ';', '&', :AND_AND, :OR_OR,
	      :LBLACK_A, :LBRACE_H, "$"

	    puts "IDENT CMPL: BEG/NO_SP" if Reish::debug_cmpl?
	    puts "CANDIDATE: ANY COMMAND" if Reish::debug_cmpl?
	    candidate_commands

	  when "=", :BANG, '|', :SYMBEG, :COLON2, ".", 
	      *Lex::Redirection2ID.values
	    puts "CANDIDATE: RESERVE(#{@lex.pretoken.token_id})" if Reish::debug_cmpl?
	    
	    command = find_argumentable_element_in_path(@lex.pretoken, path, input_unit)
	    puts "CANDIDATE: ANY COMMAND OF: #{command.inspect}" if Reish::debug_cmpl?
	    candidate_commands(command)

#	    CompCommandArg.new(nil, @lex.pretoken, [], nil, @shell).candidates
	   
	  when :LPARLEN_ARG
	    command = find_argumentable_element_in_path(@lex.pretoken, path, input_unit)
	    puts "CANDINATE: ARGUMENT OF: #{command.inspect}" if Reish::debug_cmpl?
	    candidate_argument_of(command)
	      
	    puts "CANDINATE: UNKNOWN"
	    puts "LEX STATE: #{@lex.state_sym}"
	    
	  end
	when SpecialToken
	  case @lex.pretoken.value
	  when '|', "&", "&&", "||", "$", "-", "+", "/", "*", 
	      ">=", "<=", "==", "<=>", "=~", "!~"
	    puts "CANDIDATE: SPECIAL(#{@lex.pretoken.value})" if Reish::debug_cmpl?
	    candidate_argument_of(path[-2])

	  when :MOD_IF, :MOD_UNLESS, :MOD_WHILE, :MOD_UNTIL, :MOD_RESCUE,
	      *Lex::PseudoVars, *Lex::PreservedWord.values
	    puts "CANDIDATE: RESERVE(#{@lex.pretoken.token_id})" if Reish::debug_cmpl?

	    # 未実装
	    # これらは, 変数(一般コマンド?)としてコンプレーションする必要あり

	  else
	    # ここは来ないはず
	    puts "CANDINATE: UNKNOWN"
	    puts "LEX STATE: #{@lex.state_sym}"
	  end

	when TestToken
	  puts "CANDIDATE: TEST(#{@lex.pretoken.value})" if Reish::debug_cmpl?
	  
	  sub = @lex.pretoken.value
	  (class<<Test; TestMap.keys; end).grep(/^#{sub}/).collect{|sub| "-"+sub}

	when IDToken, ID2Token
	  puts "CANDIDATE: ID(#{@lex.pretoken.value})" if Reish::debug_cmpl?
	  command = find_argumentable_element_in_path(@lex.pretoken, path, input_unit)

	  puts "COMMAND: #{command.inspect}"  if Reish::debug_cmpl?

	  candidate_commands(command)

	when PathToken
	  puts "CANDIDATE: PATH(#{@lex.pretoken.value})" if Reish::debug_cmpl?
	  candidate_path(@lex.pretoken.value)
	  
	when WordToken
	  command = find_argumentable_element_in_path(@lex.pretoken, path, input_unit)
	  puts "CANDINATE: ARGUMENT: (#{@lex.pretoken.value}) OF: #{command.inspect}" if Reish::debug_cmpl?
	  candidate_argument_of(command, @lex.pretoken)

	when StringToken
	  if @lex.lex_state?(Lex::EXPR_INSTR)
	    command = find_argumentable_element_in_path(@lex.pretoken, path, input_unit)
	    puts "CANDINATE: ARGUMENT STR(#{@lex.pretoken.inspect}) OF: #{command.inspect}" if Reish::debug_cmpl?
	    
	    candidate_argument_of(command, @lex.pretoken)
	    
	  else
	    command = find_argumentable_element_in_path(@lex.pretoken, path, input_unit)
	    puts "CANDINATE: ANY ARGUMENT OF: #{command.inspect}" if Reish::debug_cmpl?

	    # ちゃんとできていない
	    candidate_argument_of(command, @lex.pretoken)
	  end

	end
      end
    end

    ARGUMENTABLE_ELEMENT = [
      :IN,
      #CASE,
      :WHEN,
      :BREAK,
      :NEXT,
      :RAISE,
      :RETURN,
      :YIELD,
      :LBLACK_A,
      :LBRACE_H,
      :LPAREN_ARG,
#      :ID,
#      :PATH, 
#      :TEST, 
#      :SPECIAL,
    ]

    def find_argumentable_element_in_path(token, path, input_unit)
      com = nil
      for p in path.reverse
	case p
	when *ARGUMENTABLE_ELEMENT
#puts "FAE PATH: #{p.inspect}"
	  return p
	when Node::SimpleCommand
	  com = p
	when Node::PipelineCommand
	  if com && p.commands.last == com
	    return p
	  end
	end
      end
      return com if com

#puts "FAE: search in INPUT_UNIT: #{input_unit.inspect}"

      next_simplecommand = nil
      next_pipeline = nil
      input_unit.flatten.reverse.each do |n|
	case n
	when *ARGUMENTABLE_ELEMENT
#puts "FAE IU: #{n.inspect}"
	  return n
	when Node::SimpleCommand
#puts "X1"
	  com = n
#p com
	  return com if next_simplecommand
	when Node::PipelineCommand
#puts "X2"
	  if com && p.commands.last == com
#puts "X3"
	    return n
	  elsif  next_pipeline
	    n.commands.push Node::VoidSimpleCommand()
	    return n
	  end
	when SimpleToken, ReservedWordToken
#puts "X4"
	  case n.token_id
	  when "|", ".", :COLON2
#puts "X5"
	    next_pipeline = true if n == token
	  when :LPARLEN_ARG
#puts "X6"
	    next_simplecommand = true if n == token
	  end
	end
      end
#puts "X7"
      com
    end

    def find_path(list, node)
      path = []
      list.reverse.each do |tree|

	case tree
	when nil
	when Token
	  if tree.equal?(node)
	    path.push tree
	  end
	when Node
	  finder = PathFinder.new(node)
	  tree.accept(finder)
	  unless finder.path.empty?
	    path = finder.path
	  end
	when Array
	  p = find_path(tree, node)
	  if p 
	    path = p
	  end
	else
	  raise "想定していないものです(#{tree.inspect})"
	end
      end
      path
    end

    ReservedWords = [
      "BEGIN", "END",
      "alias", "and", 
      "begin", "break", 
      "case", "class",
      "def", "defined", "do",
      "else", "elsif", "end", "ensure",
      "false", "for", 
      "if", "in", 
      "module", 
      "next", "nil",
      "redo", "rescue", "retry", "return",
      "self", "super",
      "then", "true",
      "undef", "unless", "until",
      "when", "while",
      "yield",
    ]

    def candidate_commands(command = nil)
      case command
      when nil, Node::SimpleCommand
	if command
	  call = CompCommandCall.new(@shell.exenv.main,
				     command.name, [], @shell)
	else
	  call = nil
	end
	Reish::CompCmdProc(call) do |ccp|
	  l = eval("local_variables", @shell.exenv.binding).collect{|m| m.to_s}.sort
	  ccp.add l, tag: "Completing local variables:" unless l.empty?
	  c = eval("self.class.constants | Object.constants", @shell.exenv.binding).collect{|m| m.to_s}.sort
	  ccp.add c, tag: "Completing constants:" unless c.empty?
	  m = eval("methods | private_methods", @shell.exenv.binding).collect{|m| m.to_s}.sort
	  ccp.add m, tag: "Completing builtin methods:"
	  ccp.add @shell.all_commands, tag: "Completing external commands:"
	end
      when Node::PipelineCommand
	if command.commands.size == 1
	  candidate_commands(command.commands[0])
	else
	  call = CompPipelineCall.new(@shell.exenv.main, 
				      command,
				      @shell)
	  call.candidates
	end
      end
    end

    def candidate_path(path)

      cmds = []
      if /^\/[^\/]*$/ =~ path
	cmds = @shell.all_commands.collect{|c| "/"+c}.select{|e| /^#{Regexp.quote(path)}/ =~ e}
      end
      
      Dir[path+"*"].select{|p| File.executable?(p)} | cmds

    end

    # top level command call
    def candidate_argument_of(command, last_arg = nil)
      case command
      when Node::PipelineCommand
	if command.commands.size == 1
	  candidate_argument_of(command.commands[0], last_arg)
	else
	  arg = CompPipelineArg.new(@shell.exenv.main, command, last_arg, @shell)
	  arg.candidates
	end
	
      when Node::SimpleCommand
	arg = CompCommandArg.new(@shell.exenv.main,
				 command.name,
				 command.args,
				 last_arg,
				 @shell)
	arg.candidates
	
	
      else # when :IN, :WHEN, :BREAK, :NEXT, :RAISE, :RETURN, :YIELD
	raise "not implemented for command: #{command.inspect}"
      end
    end
  end
end

if Readline.respond_to?("basic_word_break_characters=")
  Readline.basic_word_break_characters= " \t\n\"\\'`><=;|&{(.:$"
end
Readline.completion_append_character = nil
#Readline.completion_proc = Reish::Completor.new(Reish::current_shell).completion_proc
