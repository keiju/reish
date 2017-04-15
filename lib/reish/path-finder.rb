#
#   completion-helper.rb - 
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

module Reish

  class PathFinder<NodeVisitor
    def initialize(target)
      @target = target
      @path = []
    end

    attr_reader :path

    def find(node)
      @path.push node
      return node if @target.equal?(node)
      block_given? && yield || @path.pop && nil
#       if block_given?
# 	r = yield
#       end
#       if r 
# 	r
#       else
# 	@path.pop
# 	nil
#       end
    end

    def visit_input_unit(input_unit)
      find(input_unit){super}
    end

    def visit_assgin_command(command)
      find(command) do 
	super do |var, val|
	  var || val
	end
      end
    end

    def visit_index_assgin_command(command)
      find(command) do
	super do |var, idx, val|
	  var || idx || val
	end
      end
    end

    def visit_index_ref_command(command)
      find(command) do 
	super do |var, idx|
	  var || idx
	end
      end
	
    end

    def visit_begin_command(command)
      find(command) do
	super do |seq, res, els, ens|
	  seq || res && res.inject(false){|r, e| r || e} || els || ens
	end
      end
    end

    def visit_rescue_command(command)
      find(command) do
	super do |el, ev, sq|
	  el.inject(false){|r, e| r || e} || ev || sq
	end
      end
    end

    def visit_if_command(command)
      find(command) do 
	super do |c, t, e|
	  c || t || e
	end
      end
    end

    def visit_while_command(command)
      find(command) do 
	super do |c, n|
	  c || n
	end
      end
    end

    def visit_until_command(command)
      find(command) do
	super do |c, n|
	  c || n
	end
      end
    end

    def visit_for_command(command)
      find(command) do
	super do |vl, en, sq|
	  vl.inject(false){|r, e| r || e} || en || sq
	end
      end
    end

    def visit_group(group)
      find(group) do 
	super do |list|
	  list.inject(false){|r, e| r || e}
	end
      end
    end

    def visit_xstring(xstring)
      find(xstring) do 
	super do |list|
	  list.inject(false){|r, e| r || e}
	end
      end
    end

    def visit_case_command(command)
      find(command) do
	super do |cd, bd, el|
	  cd || bd.inject(false){|r, e| r || e} || el
	end
      end
    end

    def visit_when_command(command)
      find(command) do
	super do |cd, sq|
	  cd.inject(false){|r, e| r || e} || sq
	end
      end
    end

    def visit_break_command(command)
      find(command) do 
	super do |ret|
	  ret.inject(false){|r, e| r || e}
	end
      end
    end

    def visit_next_command(command)
      find(command) do
	super do |ret|
	  ret.inject(false){|r, e| r || e}
	end
      end
    end

    def visit_redo_command(command)
      find(command)
    end

    def visit_retry_command(command)
      find(command)
    end

    def visit_raise_command(command)
      find(command) do
	super do |exp|
	  exp && exp.inject(false){|r, e| r || e}
	end
      end
    end

    def visit_return_command(command)
      find(command) do
	super do |ret|
	  ret && ret.inject(false){|r, e| r || e}
	end
      end
    end

    def visit_yield_command(command)
      find(command) do
	super do |args|
	  args && args.inject(false){|r, e| r || e}
	end
      end
    end

    def visit_bang_command(command)
      find(command){super}
    end

    def visit_mod_if_command(command)
      find(command) do
	super do |t, c|
	  t || c
	end
      end
    end

    def visit_mod_unless_command(command)
      find(command) do
	super do |t, c|
	  t || c
	end
      end
    end

    def visit_mod_while_command(command)
      find(command) do
	super do |t, c|
	  t || c
	end
      end
    end

    def visit_mod_until_command(command)
      find(command) do
	super do |t, c|
	  t || c
	end
      end
    end

    def visit_mod_rescue_command(command)
      find(command) do
	super do |t, a|
	  t || a
	end
      end
    end

    def visit_sequence(seq)
      find(seq) do 
	super do |s|
	  s.inject(false){|r, e| r || e}
	end
      end
    end

    def visit_async_command(command)
      find(command){super}
    end

    def visit_logical_command_aa(command)
      find(command){super{|s1, s2| s1 || s2}}
    end

    def visit_logical_command_oo(command)
      find(command){super{|s1, s2| s1 || s2}}
    end

    def visit_pipeline_command(command)
      find(command) do 
	super do |list|
	  list.inject(false){|r, e| r || e}
	end
      end
    end

    def visit_literal_command(com)
      find(com){super}
    end
    
    def visit_simple_command(command)
      case command.name
      when TestToken
# 	tk = IDToken.new(command.name.lex, "Reish::Test::test")
	
# 	sub_com = StringToken.new(command.name.lex, command.name.value)
# 	new_com = Node::SimpleCommand(tk, Node::CommandElementList.new([sub_com, *command.args]), command.block)
# 	new_com.pipeout = command.pipeout
# 	command = new_com
#puts "VISIT_SIMPLE_COMMAND: #{command.inspect}"

      when SpecialToken
	return visit_special_command(command)
      end

      if command.have_redirection?
	return visit_simple_command_with_redirection(command)
      end

      find(command) do
	super do |name, args, blk|
	  name || args && args.inject(false){|r, e| r || e} || blk
	end
      end
    end

    def visit_simple_command_with_redirection(command)
      find(command) do
	super do |name, args, blk, reds|
	  name || args.inject(false){|r, e| r || e} || blk || reds.inject(false){|r, e| r || e}
	end
      end
    end

    def visit_command_element_list(list)
      find(list) do
	super do |args|
	  args.inject(false){|r, e| r || e}
	end
      end
    end

    def visit_do_block(command)
      find(command) do
	super do |args, blk|
	  args && args.inject(false){|r, e| r || e} || blk
	end
      end
    end

    def visit_special_command(command)
      find(command) do 
	super do |op, args|
	  args.inject(false){|r, e| r || e}
	end
      end
    end

    def visit_redirector(command)
      find(command) do 
	super do |code, reds|
	  reds.inject(false){|r, e| r || e}
	end
      end
    end

    def visit_value(val)
      find(val)
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
      find(cword) do
	super do |list|
	  list.inject(false){|r, e| r || e}
	end
      end
    end

    def visit_ruby_exp(exp)
      find(exp)
    end

    def visit_word(word)
      find(word)
    end

    def visit_wildcard(wc)
      find(wc)
    end

    def visit_array(array)
      find(array) do
	super do |ary|
	  ary.inject(false){|r, e| r || e}
	end
      end
    end

    def visit_hash(array)
      find(array) do
	super do |assocs|
	  assocs.inject(false){|r, e| r || e[0] || e[1]}
	end
      end
    end

    def visit_symbol(sym)
      find(sym){super}
    end

    def visit_string(str)
      find(str)
    end

    def visit_regexp(reg)
      find(reg)
    end

    def visit_redirection(red)
      find(red) do 
	super do |s, r|
	  s || r
	end
      end
    end

    def visit_nop(nop)
      find(nop)
    end
  end
end


