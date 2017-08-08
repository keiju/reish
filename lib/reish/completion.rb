#
#   completion.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#
require "pp"

require "reish/path-finder"
require "reish/compspec"

module Reish

  class Completor

    def initialize(shell)
      @shell = shell

      @lex = Lex.new
      @parser = Parser.new(@lex)

      @parser.cmpl_mode = true
      @parser.yydebug = Reish::debug_cmpl_yy?

      @completion_proc = proc{|input|
	puts "input: #{input}" if @debug
	expr = @shell.lex.readed + Readline.line_buffer
	puts "input all: #{expr}" if @debug

	candidate(expr)
      }

      Readline.completion_proc = @completion_proc
    end

    attr_reader :completion_proc

    def candidate(str)
      if str == ""
	puts "input: ''" if Reish::debug_cmpl?
	return candidate_any_commands 
      end

      im = StringInputMethod.new(str)

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
	  puts "IDENT CMPL: BEG" if Reish::debug_cmpl?
	  puts "CANDIDATE: ANY COMMAND" if Reish::debug_cmpl?

	  candidate_commands

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
	when SimpleToken
	  case @lex.pretoken.token_id
	  when :NL, '\\', :ASSOC, :XSTRING_END, :XSTRING_BEG,
	      "(", :LBLACK_A, :LBLACK_I, :LBRACE_H, :LBRACE_I,
	      "]", ")", "}", ":", :DOT_COMMAND, ".", ';', '&', :AND_AND, :OR_OR,
	      :LBLACK_A, :LBRACE_H, "$"
	    puts "CANDIDATE: ANY COMMAND" if Reish::debug_cmpl?
	    candidate_commands

	  when :LPARLEN_ARG
	    command = find_argumentable_element_in_path(@lex.pretoken, path, input_unit)
	    puts "CANDINATE: ARGUMENT OF: #{command.inspect}" if Reish::debug_cmpl?
	    candidate_argument_of(command)
	      
	  else
	    # ここは来ないはず
	    puts "CANDINATE: UNKNOWN"
	    puts "LEX STATE: #{@lex.state_sym}"
	    
	  end
	when SpecialToken
	  case @lex.pretoken.value
	  when '|', "&", "&&", "||", "$", "-", "+", "/", "*", 
	      ">=", "<=", "==", "<=>", "=~", "!~"
	    puts "CANDIDATE: SPECIAL(#{@lex.pretoken.value})" if Reish::debug_cmpl?
	    candidate_argument_of(path[-2])
	    
	  end
	when ReservedWordToken
	  case @lex.pretoken.token_id
	  when "=", :BANG, '|', :SYMBEG, :COLON2, 
	      *Lex::Redirection2ID.values
	    puts "CANDIDATE: RESERVE(#{@lex.pretoken.token_id})" if Reish::debug_cmpl?
	    CompCommandArg.new(nil, @lex.pretoken, [], nil, @shell.exenv.binding).candidates
	   
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
	  (class<<Test; p TestMap.keys; TestMap.keys; end).grep(/^#{sub}/).collect{|sub| "-"+sub}

	when IDToken
	  puts "CANDIDATE: ID(#{@lex.pretoken.value})" if Reish::debug_cmpl?
	  candidate_commands(@lex.pretoken.value)

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
      Node::SimpleCommand
    ]

    def find_argumentable_element_in_path(token, path, input_unit)
      for p in path.reverse
	case p
	when *ARGUMENTABLE_ELEMENT
#puts "FAE PATH: #{p.inspect}"
	  return p
	end
      end

#puts "FAE: search in INPUT_UNIT: #{input_unit.inspect}"

      input_unit.flatten.reverse.each do |n|
	case n
	when *ARGUMENTABLE_ELEMENT
#puts "FAE IU: #{n.inspect}"
	  return n
	end
      end
      nil
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

    def candidate_commands(filter=nil)
      candidates = eval("methods | private_methods | local_variables | self.class.constants", @shell.exenv.binding).collect{|m| m.to_s} | @shell.all_commands
      if filter
	candidates.grep(/^#{filter}/)
      else
	candidates
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
      when Node::SimpleCommand

	arg = CompCommandArg.new(@shell.exenv.main,
				 command.name,
				 command.args,
				 last_arg,
				 @shell.exenv.binding)
	arg.candidates
	
	
      else # when :IN, :WHEN, :BREAK, :NEXT, :RAISE, :RETURN, :YIELD
	raise "not implemented for command: #{command.inspect}"
      end
    end

      
    CompletionProc2 = proc{ |input|
      shell = Reish::current_shell
      
      puts "input: #{input}"

      case input
      when /^(\/[^\/]*\/)\.([^.]*)$/
	# Regexp
puts "R"
	receiver = $1
	message = Regexp.quote($2)

	candidates = Regexp.instance_methods(true).collect{|m| m.to_s}
	select_message(receiver, message, candidates)

      when /^([^\]]*\])\.([^.]*)$/
	# Array
puts "A"
	receiver = $1
	message = Regexp.quote($2)

	candidates = Array.instance_methods(true).collect{|m| m.to_s}
	select_message(receiver, message, candidates)

      when /^([^\}]*\})\.([^.]*)$/
	# Proc or Hash
puts "PH"
	receiver = $1
	message = Regexp.quote($2)

	candidates = (Proc.instance_methods(true) | Hash.instance_methods(true)).collect{|m| m.to_s}
	select_message(receiver, message, candidates)
	
      when /^(:[^:.]*)$/
 	# Symbol
puts "S"
	if Symbol.respond_to?(:all_symbols)
	  sym = $1
	  candidates = Symbol.all_symbols.collect{|s| ":" + s.id2name}
	  candidates.grep(/^#{sym}/)
	else
	  []
	end

      when /^::([A-Z][^:\.\(]*)$/
	# Absolute Constant or class methods
puts "AC/CM"
	receiver = $1
	candidates = Object.constants.collect{|v| v.to_s}
	candidates.grep(/^#{receiver}/).collect{|e| "::" + e}

#      when /^(((::)?[A-Z][^:.\(]*)+)::?([^:.]*)$/
#      when /^[A-Z][^:.\(]*(::[A-Z][^:.\(]*)+$/
      when /^([A-Z].*)::([^:.]+)*$/
	# Constant or class methods
puts "C/CM"
	receiver = $1
	if $2
	  message = Regexp.quote($2)
	else
	  message = ""
	end
	
	begin
	  candidates = eval("#{receiver}.constants | #{receiver}.methods", bind).collect{|m| m.to_s}
	rescue Exception
	  candidates = []
	end
	candidates.grep(/^#{message}/).collect{|e| receiver + "::" + e}

      when /^(:[^:.]+)\.([^.]*)$/
	# Symbol
puts "S2"
	receiver = $1
	message = Regexp.quote($2)

	candidates = Symbol.instance_methods(true).collect{|m| m.to_s}
	select_message(receiver, message, candidates)
      #when /^([0-9_]+(\.[0-9_]+)?(e[0-9]+)?)\.([^.]*)$/

      when /^(-?(0[dbo])?[0-9_]+(\.[0-9_]+)?([eE]-?[0-9]+)?)\.([^.]*)$/
	# Numeric
puts "N"
	receiver = $1
	message = Regexp.quote($5)

	begin
	  candidates = eval(receiver, bind).methods.collect{|m| m.to_s}
	rescue Exception
	  candidates = []
	end
	select_message(receiver, message, candidates)

      when /^(-?0x[0-9a-fA-F_]+)\.([^.]*)$/
	# Numeric(0xFFFF)
puts "N2"
	receiver = $1
	message = Regexp.quote($2)

	begin
	  candidates = eval(receiver, bind).methods.collect{|m| m.to_s}
	rescue Exception
	  candidates = []
	end
	select_message(receiver, message, candidates)

      when /^(\$[^.]*)$/
puts "G"
	candidates = global_variables.grep(Regexp.new(Regexp.quote($1)))

#      when /^(\$?(\.?[^.]+)+)\.([^.]*)$/
#      when /^((\.?[^.]+)+)\.([^.]*)$/
      when /^([^."].*)\.([^.]*)$/
	# variable
puts "V"
	receiver = $1
	if $2
	  message = Regexp.quote($2)
	else
	  message = ""
	end

	p receiver
	p message

	gv = eval("global_variables", bind).collect{|m| m.to_s}
	lv = eval("local_variables", bind).collect{|m| m.to_s}
	cv = eval("self.class.constants", bind).collect{|m| m.to_s}
	
	if (gv | lv | cv).include?(receiver)
	  # foo.func and foo is local var.
	  candidates = eval("#{receiver}.methods", bind).collect{|m| m.to_s}
	elsif /^[A-Z]/ =~ receiver and /\./ !~ receiver
	  # Foo::Bar.func
	  begin
	    candidates = eval("#{receiver}.methods", bind).collect{|m| m.to_s}
	  rescue Exception
	    candidates = []
	  end
	else
	  # func1.func2
	  candidates = []
	  ObjectSpace.each_object(Module){|m|
	    begin
	      name = m.name
	    rescue Exception
	      name = ""
	    end
	    next if name != "IRB::Context" and 
	      /^(IRB|SLex|RubyLex|RubyToken)/ =~ name
	    candidates.concat m.instance_methods(false).collect{|x| x.to_s}
	  }
	  candidates.sort!
	  candidates.uniq!
	end
	select_message(receiver, message, candidates)

      when /^\.([^.]*)$/
	# unknown(maybe String)
puts "U"

	receiver = ""
	message = Regexp.quote($1)

p message

	candidates = String.instance_methods(true).collect{|m| m.to_s}
	select_message(receiver, message, candidates)

      else
puts "E"
	candidates = eval("methods | private_methods | local_variables | self.class.constants", bind).collect{|m| m.to_s}
			  
	(candidates|ReservedWords).grep(/^#{Regexp.quote(input)}/)
      end
    }

    Operators = ["%", "&", "*", "**", "+",  "-",  "/",
      "<", "<<", "<=", "<=>", "==", "===", "=~", ">", ">=", ">>",
      "[]", "[]=", "^",]

    def self.select_message(receiver, message, candidates)
      candidates.grep(/^#{message}/).collect do |e|
	case e
	when /^[a-zA-Z_]/
	  receiver + "." + e
	when /^[0-9]/
	when *Operators
	  #receiver + " " + e
	end
      end
    end
  end

end

if Readline.respond_to?("basic_word_break_characters=")
  Readline.basic_word_break_characters= " \t\n\"\\'`><=;|&{("
end
Readline.completion_append_character = nil
#Readline.completion_proc = Reish::Completor.new(Reish::current_shell).completion_proc
