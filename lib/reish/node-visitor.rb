#
#   node-visitor.rb - 
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

    def visit_input_unit(input_unit)
      yield input_unit.node.accept(self)
    end


    def visit_assgin_command(command)
      var = command.variable.accept(self)
      val = command.value.accept(self)
      yield var, val
    end

    def visit_index_assgin_command(command)
      var = command.variable.accept(self)
      idx = command.index.accept(self)
      val = command.value.accept(self)
      yield var, idx, val
    end

    def visit_index_ref_command(command)
      var = command.variable.accept(self)
      idx = command.index.accept(self)

      yield var, idx
    end
    
    def visit_begin_command(command)
      seq = command.seq.accept(self)

      case command.res
      when nil
	res = nil
      when Array
	res = command.res.collect{|r| r.accept(self)}
      else
	res = [command.res.accept(self)]
      end

      els = nil
      if command.els
	els = command.els.accept(self)
      end

      ens = nil
      if command.ens
	command.ens.accept(self)
      end

      yield seq, res, els, ens
    end

    def visit_rescue_command(command)
      el = command.exc_list.collect{|exc| exc.accept(self)}
      sq = command.seq.accept(self)
      ev = nil
      if command.exc_var
	ev = command.exc_var.accept(self) 
      end

      yield el, ev, sq
    end


    def visit_if_command(command)
      c = command.cond.accept(self)
      t = command.then_list && command.then_list.accept(self) 
      e = command.else_list && command.else_list.accept(self)

      yield c, t, e
    end

    def visit_while_command(command)
      c = command.cond.accept(self)
      n = command.node.accept(self)

      yield c, n
    end

    def visit_until_command(command)
      c = command.cond.accept(self)
      n = command.node.accept(self)
      
      yield c, n
    end

    def visit_group(group)
      yield group.nodes.collect{|n| n.accept(self)}
    end

    def visit_xstring(xstring)
      yield xstring.nodes.collect{|n| n.accept(self)}
    end

    def visit_case_command(command)
      cd = command.cond.accept(self)
      if command.body.last.kind_of?(Node::Sequence)
	el = command.body.pop.accept(self)
	bd = command.body.collect{|b| b.accept(self)}
	yield cd, bd, el
      else
	bd = command.body.collect{|b| b.accept(self)}
	yield cd, bd, nil
      end
    end

    def visit_when_command(command)
      cd = command.cond.collect{|e| e.accept(self)}
      sq = command.seq.accept(self)
      yield cd, sq
    end

    def visit_break_command(command)
      ret = command.args && command.args.collect{|e| e.accept(self)}
      yield ret
    end

    def visit_next_command(command)
      ret = command.args.collect{|e| e.accept(self)}
      yield ret
    end

    def visit_redo_command(command)
      yield 
    end

    def visit_retry_command(command)
      uield
    end

    def visit_raise_command(command)
      exp = command.args && command.args.collect{|e| e.accept(self)}
      yield exp
    end

    def visit_return_command(command)
      ret = command.args && command.args.collect{|e| e.accept(self)}
      yield ret
    end

    def visit_yield_command(command)
      args = command.args && command.args.collect{|e| e.accept(self)}
      yield args
    end

    def visit_bang_command(command)
      com = command.com.accept(self)
      yield com
    end

    def visit_mod_if_command(command)
      t = command.com.accept(self)
      c = command.cond.accept(self)
      yield t, c
    end

    def visit_mod_unless_command(command)
      t = command.com.accept(self)
      c = command.cond.accept(self)
      yield t, c
    end

    def visit_mod_while_command(command)
      t = command.com.accept(self)
      c = command.cond.accept(self)
      yield t, c
    end

    def visit_mod_until_command(command)
      t = command.com.accept(self)
      c = command.cond.accept(self)
      yield t, c
    end

    def visit_mod_rescue_command(command)
      t = command.com.accept(self)
      a = command.args.collect{|a| a.accept(self)}.join(", ")
      yield t, a
    end

    def visit_sequence(seq)
      s = seq.nodes.collect{|n| n.accept(self)}
      yield s
    end

    def visit_async_command(command)
      s = command.subcommand.accept(self)
      yield s
    end

    def visit_logical_command_aa(command)
      s1 = command.first.accept(self)
      s2 = command.second.accept(self)
      yield s1, s2
    end

    def visit_logical_command_oo(command)
      s1 = command.first.accept(self)
      s2 = command.second.accept(self)
      yield s1, s2
    end

    def visit_pipeline_command(command)
      list = command.commands.collect{|com| com.accept(self)}
      yield list
    end

    def visit_literal_command(com)
      code = com.value.accept(self)
      yield code
    end

    def visit_simple_command(command)
      name = command.name.accept(self)
      args = command.args.collect{|e| e.accept(self)}
      blk = command.block && command.block.accept(self) 
      yield name, args, blk
    end

    def visit_simple_command_with_redirection(command)

      name = command.name.accept(self)
      args = []
      reds = []
      command.args.each do |e|
	case e
	when Node::Redirection
	  reds.push e.accept(self)
	else
	  args.push e.accept(self)
	end
      end
      blk = command.block && command.block.accept(self) 

      yield name, args, blk, reds
    end


    def visit_do_block(command)
      args = command.args && command.args.collect{|e| e.accept(self)}
      blk = command.body.accept(self)

      yield args, blk
    end

    def visit_special_command(command)
      op = command.name.accept(self)
      args = command.args.collect{|e| e.accept(self)}
      yield op, args
    end

    def visit_redirector(command)
      code = command.node.accept(self)
      reds = command.reds.collect{|e| e.accept(self)}
      yield code, reds
    end

    def visit_value(val)
      val.value
    end
    alias visit_id visit_value
    alias visit_test visit_value
    alias visit_path visit_value
    alias visit_number visit_value
    alias visit_integer visit_value
    alias visit_fid visit_value
    alias visit_pseudo_variable visit_value
    alias visit_variable visit_value

    def visit_composite_word(cword)
      yield cword.elements.collect{|e| e.accept(self)}
    end

    def visit_array(array)
      yield array.elements.collect{|e| e.accept(self)}
    end

    def visit_hash(array)
      assocs = array.elements.collect{|e1, e2| [e1.accept(self), e2.accept(self)]}
      yield assocs
    end

    def visit_symbol(sym)
      yield sym.value.accept(self)
    end

    def visit_redirection(red)
      if red.source.kind_of?(Integer)
	s = red.source
      else
	s = red.source.accept(self)
      end
      if red.red.kind_of?(Integer)
	r = red.red
      else
	r = red.red.accept(self)
      end
      yield s, r
    end
  end
end
