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

  class CodeGenerator<NodeVisitor

    def visit_input_unit(input_unit)
      super{|v| v}
    end

    def visit_assgin_command(command)
      super do |var, val|
	"(#{var}=#{val})"
      end
    end

    def visit_index_assgin_command(command)
      super do |var, idx, val|
	"(#{var}[#{idx}]=#{val})"
      end
    end

    def visit_index_ref_command(command)
      super do |var, idx|
	"#{var}[#{idx}]"
      end
    end

    def visit_begin_command(command)
      super do |seq, res, els, ens|
	code_res = res && "; #{res.join(";")}" || ""
	code_els = els && "; else #{els}" || ""
	code_ens = ens && "; ensure #{ens}" || ""

	code = "begin #{seq}#{code_res}#{code_els}#{code_ens} end"
	if command.pipein
	  "reish_eval(%{#{code}}, binding)"
	else
	  code
	end
      end
    end

    def visit_rescue_command(command)
      super do |el, ev, sq|
	elc = el.join(", ")
	if ev
	  "rescue #{elc} => #{ev}; #{sq}"
	else
	  "rescue #{elc}; #{sq}"
	end
      end
    end

    def visit_if_command(command)
      super do |c, t, e|

	code_t = t && " then #{t}" || ""
	code_e = e && " else #{e}" || ""
	code = "if #{c}#{code_t}#{code_e} end"

	if command.pipein
	  "reish_eval(%{#{code}}, binding)"
	else
	  code
	end
      end
    end

    def visit_while_command(command)
      super do |c, n|
	code = "while #{c} do #{n} end"
	if command.pipein
	  "reish_eval(%{#{code}}, binding)"
	else
	  code
	end
      end
    end

    def visit_until_command(command)
      super do |c, n|
	code = "until #{c} do #{n} end"
	if command.pipein
	  "reish_eval(%{#{code}}, binding)"
	else
	  code
	end
      end
    end

    def visit_for_command(command)
      vl = command.vars.collect{|v| v.accept(self)}.join(", ")
      en = command.enum.accept(self)
      sq = command.seq.accept(self)

      code = "for #{vl} in #{en} do #{sq} end"
      if command.pipein
	"reish_eval(%{#{code}}, binding)"
      else
	code
      end
    end

    def visit_group(group)
      super do |list|
	code = "(#{list.join("; ")})"
	if group.pipein
	  "reish_eval(%{#{code}}, binding)"
	else
	  code
	end
      end
    end

    def visit_xstring(xstring)
      super do |list|
	code = "Reish::ConcatCommand.new(#{list.join(", ")}).reish_result"
	if xstring.pipein
	  "reish_eval(%{#{code}}, binding)"
	else
	  code
	end
      end
    end

    def visit_case_command(command)
      super do |cd, bd, el|

	code_el = el && "else #{el}; " || ""
	code = "case #{cd}; #{bd.join("; ")}; #{code_el}end"

	if command.pipein
	  "reish_eval(%{#{code}}, binding)"
	else
	  code
	end
      end
    end

    def visit_when_command(command)
      super do |cd, sq|
	code = "when #{cd.join(", ")}; #{sq}"
	if command.pipein
	  "reish_eval(%{#{code}}, binding)"
	else
	  code
	end
      end
    end

    def visit_break_command(command)
      super do |ret|
	"break #{ret && ret.join(", ") || ""};"
      end
    end

    def visit_next_command(command)
      super do |ret|
	"next #{ret && ret.join(", ") || ""};"
      end
    end

    def visit_redo_command(command)
      "redo;"
    end

    def visit_retry_command(command)
      "retry;"
    end

    def visit_raise_command(command)
      super do |exp|
	"raise #{exp && exp.join(", ") || ""};"
      end
    end

    def visit_return_command(command)
      super do |ret|
	"return #{ret && ret.join(", ") || ""};"
      end
    end

    def visit_yield_command(command)
      super do |args|
	"yield #{args && args.join(", ") || ""};"
      end
    end

    def visit_bang_command(command)
      super do |com|
	"!#{com}"
      end
    end

    def visit_mod_if_command(command)
      super do |t, c|
	"#{t} if #{c}; "
      end
    end

    def visit_mod_unless_command(command)
      super do |t, c|
	"#{t} unless #{c}; "
      end
    end

    def visit_mod_while_command(command)
      super do |t, c|
	"#{t} while #{c}; "
      end
    end

    def visit_mod_until_command(command)
      super do |t, c|
	"#{t} until #{c}; "
      end
    end

    def visit_mod_rescue_command(command)
      super do |t, a|
	"#{t} rescue #{a}; "
      end
    end

    def visit_sequence(seq)
      super do |s|
	case seq.pipeout
	when :BAR, :COLON2, :DOT
	  "Reish::ConcatCommand.new(#{s.join(", ")})"
	when :TO_A
	  "Reish::ConcatCommand.new(#{s.join(", ")}).resish_result"
	when :RESULT
	  "(#{s.join("; ")}).reish_result"
	else
	  s.join("; ")
	end
      end
    end

    def visit_async_command(command)
      super do |s|
	"Reish::JobStart{#{s}}"
      end
    end

    def visit_logical_command_aa(command)
      super do |s1, s2|
	"(#{s1} && #{s2})"
      end
    end

    def visit_logical_command_oo(command)
      super do |s1, s2|
	"(#{s1} || #{s2})"
      end
    end

    def visit_pipeline_command(command)
      super do |list|
	script = ""
	command.commands.zip(list) do |com, s|
	  script.concat s

	  unless com.kind_of?(Node::SimpleCommand)
	    case com.pipeout
	    when :BAR, :DOT
	      script.concat "."
	    when :COLON2
	      script.concat "::"
	    when :TO_A
	      script.concat ".to_a"
	    when :RESULT
	      script.concat ".reish_result"
	    when nil, :NONE
	      # do nothing
	    else
	      raise NoImplementError
	    end
	  end
	end

	case command.pipeout
	when :BAR, :DOT
	  script.concat "."
	when :COLON2
	  script.concat "::"
	when :TO_A
	  script.concat ".to_a"
	when :RESULT
	  script.concat ".reish_result"
	when :NONE
	  # do nothing
	when nil
	  script.concat ".reish_term"
	else
	  raise NoImplementError
	end
	script
      end
    end

    def visit_literal_command(com)
      super do |code|
	if com.pipein
	  "reish_eval(%{#{code}}, binding)"
	else
	  code
	end
      end
    end
    
    def visit_simple_command(command)
      case command.name
      when TestToken
	tk = IDToken.new(command.name.lex, "Reish::Test::test")
	
	sub_com = StringToken.new(command.name.lex, command.name.value)
	new_com = Node::SimpleCommand(tk, Node::CommandElementList.new([sub_com, *command.args]), command.block)
	new_com.pipeout = command.pipeout
	command = new_com
      when SpecialToken
	return visit_special_command(command)
      end

      if command.have_redirection?
	return visit_simple_command_with_redirection(command)
      end

      super do |name, args, blk|
	if !command.name.kind_of?(PathToken)
	  argc = args.empty? && "" || "(#{args.join(", ")})"
	  script = "#{name}#{argc}#{blk || ""}"
	else
	  argc = args.empty? && "" || ", #{args.join(", ")}"
	  script = "send('#{name}'#{argc})#{blk || ""}"
	end

	case command.pipeout
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
	script
      end
    end

    def visit_simple_command_with_redirection(command)
      super do |name, args, blk, reds|
	"reish_send_with_redirection('#{name}', [#{args.join(", ")}], [#{reds.join(", ")}])#{command.block || ""}"
	end
    end

    def visit_do_block(command)
      super do |args, blk|
	argc = args && "|"+args.join(", ")+"|" || ""
	"{#{argc} #{blk}}"
      end
    end

    def visit_special_command(command)

      super do |op, args|
	script = "(#{args.join(op)})"

	case command.pipeout
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

	script
      end
    end

    def visit_redirector(command)
      super do |code, reds|
	"reish_shell_command_with_redirection(\'#{code}\', [#{reds.join(",")}], binding).reish_term"
      end
    end

#     def visit_value(val)
#       val.value
#     end
#     alias visit_id visit_value
#     alias visit_test visit_value
#     alias visit_path visit_value
#     alias visit_number visit_value
#     alias visit_integer visit_value
#     alias visit_fid visit_value
#     alias visit_pseudo_variable visit_value
#     alias visit_variable visit_value


#    def visit_variable(val)
#      "((defined? #{val.value}) ? #{val.value} : (raise NameError, \"undefined variable `#{val.value}' for #{self}\"))"
#    end

    def visit_composite_word(cword)
      wc = false
      str = cword.elements.collect{|e| 
 	case e
 	when WordToken
 	  e.accept(self)
 	when WildCardToken
 	  wc = true
 	  e.accept(self)
 	else
 	  '(' + e.accept(self) +').to_s'
 	end
      }.join("+")
      str = "("+str+").reish_result" if wc
      str
    end

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
      super do |ary|
	"[#{ary.join(", ")}]"
      end
    end

    def visit_hash(array)
      super do |assocs|
	"{#{assocs.collect{|assoc| "#{assoc[0]}=>#{assoc[1]}"}.join(", ")}}"
      end
    end

    def visit_symbol(sym)
      super do |s|
	":#{s}"
      end
    end

    def visit_string(str)
      '"'+str.value+'"'
    end

    def visit_regexp(reg)
      '/'+reg.value+'/'
    end

    def visit_redirection(red)
      super do |s, r|
	if red.over
	  "Reish::Redirect(#{s}, '#{red.id}', #{r}, #{red.over})"
	else
	  "Reish::Redirect(#{s}, '#{red.id}', #{r})"
	end
      end
    end

    def visit_nop(nop)
      "\n"
    end
  end
end
