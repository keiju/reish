#
#   shell.rb - 
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

require "reish/lex.rb"
require "reish/parser.rb"
require "reish/codegen.rb"

module Reish 
  class Shell
    def initialize
      @lex = Lex.new
      @parser = Parser.new(@lex)
      @codegen = CodeGenerator.new
    end

    def start
      @lex.set_prompt do |ltype, indent, continue, line_no|
	"reish>"
      end

      @lex.set_input(STDIN)
      eval_input
    end

    def eval_input
      loop do
	@current_input_unit = @parser.do_parse
	p @current_input_unit
	break if Node::EOF == @current_input_unit 
	if Node::NOP == @current_input_unit 
	  puts "OUTPUT: (NL)"
	  next
	end
	exp = @current_input_unit.accept(@codegen)
	puts "OUTPUT: #{exp}"
      end
    end
  end
end
