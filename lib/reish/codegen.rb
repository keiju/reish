#
#   codegen.rb - 
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

module Reish
  class NodeVisitor
  end

  class CodeGenerator<NodeVisitor

    def visit_input_unit(input_unit)
      input_unit.node.accept(self)
    end

    def visit_while_command(command)
      c = command.cond.accept(self)
      n = command.node.accept(self)
      
      "WHILE(#{c}, #{n})"
    end

    def visit_if_command(command)
      c = command.cond.accept(self)
      t = nil
      t = command.then_list.accept(self)if command.then_list

      e = nil
      e = command.else_list.accept(self) if command.else_list

      if e
	"IF(#{c}, #{t}, #{e})"
      else
	"IF(#{c}, #{t})"
      end
    end

    def visit_group(group)
      script = group.node.accept(self)
      "("+script+")"
    end

    def visit_seq_command(command)
      script = command.nodes.collect{|n| n.accept(self)}.join("; ")
      "("+script+")"
    end

    def visit_async_command(command)

      s = command.subcommand.accept(self)
      "Reish::JobStart{#{s}}"
    end

    def visit_logical_command_aa(command)
      s1 = command.first.accept(self)
      s2 = command.second.accept(self)
      "(#{s1} && #{s2})"
    end

    def visit_logical_command_oo(command)
      s1 = command.first.accept(self)
      s2 = command.second.accept(self)
      "(#{s1} || #{s2})"
    end

    def visit_pipeline_command(command)
      s = command.commands.collect{|com| com.accept(self)}.join(".")
      "#{s}.reish_stat"
    end

    def visit_simple_command(command)
      name = command.name.accept(self)

      if command.have_redirection?
	return visit_simple_command_with_redirection(command)
      end
      if command.args.empty?
	args = ""
      else
	args = "("+command.args.collect{|e| e.accept(self)}.join(", ")+")"
      end
      if command.block
	"#{name}#{args}{#{command.block.accept(self)}}"
      else
	"#{name}#{args}"
      end
    end

    def visit_simple_command_with_redirection(command)
      name = command.name.accept(self)

      args = command.args.collect{
	|e|
	case e
	when Node::Redirection
	  '('+e.accept(self)+")"
	else
	  e.accept(self)
	end
      }.join(", ")
      if command.block
	"#{name}(#{args}){#{command.block.accept(self)}}"
      else
	"#{name}(#{args})"
      end
    end

    def visit_ruby_exp(exp)
      "("+exp.exp+")"
    end

    def visit_id(id)
      id.value
    end

    def visit_word(id)
      '"'+id.value+'"'
    end

    def visit_redirection(red)
      "#{red.source}#{red.id}#{red.red.accept(self)}#{red.over}"
    end

    def visit_nop(nop)
      "\n"
    end
  end
end

