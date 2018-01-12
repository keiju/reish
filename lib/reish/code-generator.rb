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


require "reish/node-visitor"
require "reish/function"

module Reish

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

    def visit_class_command(command)
      super do |klass, sklass, body|
	if sklass
	  %{class #{klass}<#{sklass}
	      #{body}
	    end}
	else
	  %{class #{klass}
	      #{body}
	    end}
	end
      end
    end

    DirectCallFunctions = [
      :initialize,
      :each
    ]
    DirectCallFunctionSet = {}
    DirectCallFunctions.each do |f|
      DirectCallFunctionSet[f] = f
      DirectCallFunctionSet[f.id2name] = f
    end

    def visit_def_command(command)
      super do |name, args, body|
	if DirectCallFunctionSet[name]
	  def_direct_command(command, name, args, body)
	else
	  def_command(command, name, args, body)
	end
      end
    end

    def def_direct_command(command, name, args, body)
	ags = args && args.join(", ") || ""
	code = body.accept(self)

	script = %{def #{name}(#{ags})
	  #{code}
	 end
        }
	if Reish::debug_function?
	  puts script
	end
      script
    end

    def def_command(command, name, args, body)

      ags = args && args.join(", ")

      fclass = FunctionFactory::define_function(UserFunctionSpace, name, args, body, self)

      ag = args && ", #{ags}" || ""
      if command.id.kind_of?(IDToken)
	%{reish_user_function_space_eval %{
	    def #{name}(#{ags})
	      #{fclass.name}.new(self#{ag})
	    end
	  }}
      else
        ab = args && "|#{ags}|" || ""
        %{reish_user_function_space_eval %{
	    define_method(:'#{name}'){#{ab}
	      #{fclass.name}.new(self#{ag})
	    }
	  }}
      end
    end



    def visit_alias_command(command)
      super do |id, pl|
	if command.id.kind_of?(ID2Token)
	  id = ":'#{id}'"
	end
	if command.pipeline.kind_of?(ID2Token)
	  pl = ":'#{pl}'"
	end

	"alias #{id} #{pl}"
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
      super do |vl, en, sq|
	code = "for #{vl.join(", ")} in #{en} do #{sq} end"
	if command.pipein
	  "reish_eval(%{#{code}}, binding)"
	else
	  code
	end
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
	  "(#{s.join("; ")})"
	when :TO_A
	  "Reish::ConcatCommand.new(#{s.join(", ")}).resish_result"
	when :RESULT, :RESULTL
	  "(#{s.join("; ")})"
	when :NONE
	  "(#{s.join("; ")})"
	else
	  s.join("; ")
	end
      end
    end

    def visit_async_command(command)
      super do |s|
	"background_job(\"#{s}\"){#{s}}"
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

  	  unless [Node::SimpleCommand, Node::LiteralCommand].find{|klass| com.kind_of?(klass)}
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
  	    when :XNULL
  	      script.concat ".reish_xnull"
  	    when :RESULTL
  	      script.concat ".reish_resultl"
  	    else
  	      raise NoImplementError
  	    end
  	  end
 	end

#   	case command.pipeout
#   	when :BAR, :DOT
#   	  script.concat "."
#   	when :COLON2
#   	  script.concat "::"
#   	when :TO_A
#   	  script.concat ".to_a"
#   	when :RESULT
#   	  script.concat ".reish_result"
#   	when :NONE
#   	  # do nothing
#   	when nil
#   	  script.concat ".reish_term"
#   	when :XNULL
#   	  script.concat ".reish_xnull"
#   	else
#   	  p command
#   	  raise NoImplementError
#   	end
	script
      end
    end

    def visit_literal_command(com)
      super do |lit|
	if com.pipein
	  code = "reish_eval(%{#{lit}}, binding)"
	else
	  code = lit
	end

	case com.pipeout
	when :BAR, :DOT
	  code.concat "."
	when :COLON2
	  code.concat "::"
	when :TO_A
	  code.concat ".to_a"
	when :RESULT, :RESULTL, :XNULL, :NONE
	  # do nothing
	when nil
	  code.concat ".reish_term"
	else
	  raise NoImplementError
	end
	code
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
	case command.name
	when IDToken
	  argc = args.empty? && "" || "(#{args.join(", ")})"
	  script = "#{name}#{argc}#{blk || ""}"
	when ID2Token, PathToken
	  argc = args.empty? && "" || ", #{args.join(", ")}"
	  script = "send('#{name}'#{argc})#{blk || ""}"
	else
	  raise InternalError, "想定していないものです(#{command.name.inspect})"
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
	when :RESULTL
	  script.concat ".reish_resultl"
	when :XNULL
	  script.concat ".reish_xnull"
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

    def visit_simple_command_with_redirection(command)
      super do |name, args, blk, reds|
	script = "reish_send_with_redirection('#{name}', [#{args.join(", ")}], [#{reds.join(", ")}])#{blk || ""}"

	case command.pipeout
	when :BAR, :DOT
	  script.concat "."
	when :COLON2
	  script.concat "::"
	when :TO_A
	  script.concat ".to_a"
	when :RESULT
	  script.concat ".reish_result"
	when :XNULL
	  script.concat ".reish_xnull"
	when :NONE
	  # do nothing
	when nil
	  script.concat ".reish_term"

	else
	  raise NoImplementError
	end

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
	when nil, :NONE
	  # do nothing
	else
	  raise NoImplementError
	end

	script
      end
    end

    def visit_redirector(command)
      super do |code, reds|
	"reish_shell_command_with_redirection(\'#{code}\', [#{reds.join(",")}], binding)"
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
