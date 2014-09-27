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

    def visit_assgin_command(command)
      var = command.variable.accept(self)
      val = command.value.accept(self)

      "#{var}=#{val}"
    end

    def visit_index_assgin_command(command)
      var = command.variable.accept(self)
      idx = command.index.accept(self)
      val = command.value.accept(self)

      "#{var}[#{idx}]=#{val}"
    end

    def visit_index_ref_command(command)
      var = command.variable.accept(self)
      idx = command.index.accept(self)

      "#{var}[#{idx}]"
    end

    def visit_while_command(command)
      c = command.cond.accept(self)
      n = command.node.accept(self)
      
      "(while #{c} do #{n} end)"
    end

    def visit_if_command(command)
      c = command.cond.accept(self)
      t = nil
      t = command.then_list.accept(self)if command.then_list

      e = nil
      e = command.else_list.accept(self) if command.else_list

      if t
	if e
	  "(if(#{c}) then #{t} else #{e} end)"
	else
	  "(if(#{c}) then #{t} end)"
	end
      elsif e
	"(if(#{c}) else #{e} end)"
      else
	"(if (#{c}) end))"
      end
    end

    def visit_group(group)
      script = group.node.accept(self)
      "("+script+")"
    end

    def visit_sequence(seq)
      case seq.pipeout
      when :BAR, :COLON2, :DOT
	s = seq.nodes.collect{|n| n.accept(self)}.join(", ")
	"Reish::ConcatCommand.new(#{s})"
      when :TO_A
	s = seq.nodes.collect{|n| n.accept(self)}.join(", ")
	"Reish::ConcatCommand.new(#{s}).resish_result"
      when :RESULT
	"("+seq.nodes.collect{|n| n.accept(self)}.join("; ")+").reish_result"
      else
	seq.nodes.collect{|n| n.accept(self)}.join("; ")
      end
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
      script = ""
      command.commands.each do |com|
	script.concat com.accept(self)
	case com.pipeout
	when :BAR, :DOT
	  script.concat "."
	when :COLON2
	  script.concat "::"
	when :TO_A
	  script.concat ".to_a"
	when :RESULT
	  script.concat ".reish_result"
	when nil
	  # do nothing
	else
	  raise NoImplementError
	end
      end
      
      script.concat ".reish_term" unless command.pipeout
      script
    end

    def visit_literal_command(com)
      com.value.accept(self)
    end

    def visit_simple_command(command)
      if command.have_redirection?
	return visit_simple_command_with_redirection(command)
      end

      name = command.name.accept(self)

      if !command.name.kind_of?(PathToken)
	if command.args.empty?
	  args = ""
	else
	  args = "("+command.args.collect{|e| e.accept(self)}.join(", ")+")"
	end
	if command.block
	  "#{name}#{args}#{command.block.accept(self)}"
	else
	  "#{name}#{args}"
	end
      else
	if command.args.empty?
	  args = ""
	else
	  args = ","+command.args.collect{|e| e.accept(self)}.join(", ")
	end
	if command.block
	  "send('#{name}'#{args})#{command.block.accept(self)}"
	else
	  "send('#{name}'#{args})"
	end
      end
    end

    def visit_do_block(command)
      b = command.body.accept(self)
      
      args = ""
      if command.args
	args = "|"+command.args.collect{|e| e.accept(self)}.join(", ")+"|"
      end
      "{#{args} #{b}}"
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

    def visit_value(val)
      val.value
    end
    alias visit_id visit_value
    alias visit_path visit_value
    alias visit_number visit_value
    alias visit_integer visit_value
    alias visit_fid visit_value
    alias visit_pseudo_variable visit_value
    alias visit_variable visit_value

#    def visit_variable(val)
#      "((defined? #{val.value}) ? #{val.value} : (raise NameError, \"undefined variable `#{val.value}' for #{self}\"))"
#    end


    def visit_ruby_exp(exp)
      "("+exp.exp+")"
    end

    def visit_word(word)
      '"'+word.value+'"'
    end

    def visit_wildcard(wc)
      'Reish::WildCard("'+wc.value+'")'
    end

    def visit_array(array)
      script = array.elements.collect{|e| e.accept(self)}.join(", ")
      "["+script+"]"
    end

    def visit_hash(array)
      script = array.elements.collect{|e1, e2| e1.accept(self)+"=>"+e2.accept(self)}.join(", ")
      "{"+script+"}"
    end

    def visit_symbol(sym)
      ":" + sym.value.accept(self)
    end

    def visit_string(str)
      '"'+str.value+'"'
    end


    def visit_regexp(reg)
      '/'+reg.value+'/'
    end

    def visit_redirection(red)
      s = red.source.accept(self)
      r = red.red.accept(self)
      "Reish::Redirect(#{s}, '#{red.id}', #{r}, #{red.over})"
    end

    def visit_nop(nop)
      "\n"
    end
  end
end

