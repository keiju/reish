#
#   reish/node.rb - 
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

  class Node
    def Node.def_constructor(n=nil)
      n = name unless n
      
      n.gsub!(/^.*::/, "")

      Node.instance_eval("def #{n}(*opts); Node::#{n}.new(*opts); end")

    end

    def Node.def_accept(n=nil)

      unless n
	c = name

	c.gsub!(/^.*::/, "")
	n = c.scan(/([A-Z][a-z]*)/).collect{|m| m[0].downcase}.join("_")
      end
      class_eval "def accept(v); v.visit_#{n}(self); end"
    end


    class ValueNode<Node
      def initialize(val)
	super()
	@value = val
      end

      attr_reader :value
    end

    class SingleNode<Node
      def initialize(token)
	@token = token
      end
      attr_reader :token
    end


    class InputUnit<Node
      def_constructor

      def initialize(top, term)
	@node = top
	@term = term
      end

      attr_reader :node
      attr_reader :term

      def_accept
    end

    class Command<Node
      def intialize
	@pipein = nil
	@pipeout = nil
	@have_redirection = nil
      end

      attr_accessor :pipein
      attr_accessor :pipeout
    end

    class LogicalCommand<Node
      def_constructor

      def initialize(com1, com2, op)
	@first = com1
	@second = com2
	@connector = op
      end

      attr_reader :first
      attr_reader :second
      attr_reader :op

      def_accept
    end

    class LogicalCommandAA<LogicalCommand
      def_constructor

      def initialize(com1, com2)
	super com1, com2, "&&"
      end

      def_accept "logical_command_aa"
    end

    class LogicalCommandOO<LogicalCommand
      def_constructor

      def initialize(com1, com2=nil)
	super com1, com2, "||"
      end

      def_accept "logical_command_oo"
    end

    class BangCommand<Command
      def_constructor

      def initialize(com)
	@com = com
      end
      
      attr_reader :com

      def_accept
    end

    class PipelineCommand<Command
      def_constructor

      def initialize(com)
	super()
	@commands = [com]
      end
      attr_reader :commands

      def pipeout=(val)
	@pipeout = val
#	@commands.last.pipeout = val
      end
      
      def pipe_command(attr, com)
	@commands.last.pipeout = attr
	case com
	when Node::PipelineCommand
	  com0 = nil
	  com.commands.each do |c|
	    unless com0
	      com0 = c
	      com0.pipein = true
	    end
	    @commands.push c
	  end
	else
	  com.pipein = true
	  @commands.push com
	end
      end

      def_accept
    end

    class AssginCommand<Command
      def_constructor

      def initialize(var, val)
	@variable = var
	@value = val

	begin
	  @value.pipeout=:RESULT
	rescue Exception
	  #literalの時
	end
      end

      attr_reader :variable
      attr_reader :value

      def_accept
    end

    class IndexAssginCommand<Command
      def_constructor

      def initialize(var,index,  val)
	@variable = var
	@index = index
	@value = val

	begin
	  @value.pipeout=:RESULT
	rescue Exception
	end
      end

      attr_reader :variable
      attr_reader :index
      attr_reader :value

      def_accept
    end

    class IndexRefCommand<Command
      def_constructor

      def initialize(var,index)
	@variable = var
	@index = index

	@variable.pipeout = :RESULT
      end

      attr_reader :variable
      attr_reader :index

      def_accept
    end

    class BeginCommand<Command
      def_constructor
      
      def initialize(seq, res, els, ens)
	@seq = seq
	@res = res
	@els = els
	@ens = ens
      end

      attr_reader :seq
      attr_reader :res
      attr_reader :els
      attr_reader :ens

      def_accept
    end

    class RescueCommand<Command
      def_constructor
      
      def initialize(exc_list, exc_var, seq)
	@exc_list = exc_list
	@exc_var = exc_var
	@seq = seq
      end

      attr_reader :exc_list
      attr_reader :exc_var
      attr_reader :seq

      def_accept
    end
      

    class IfCommand<Command
      def_constructor

      def initialize(cond, then_list=nil, else_list=nil)
	@cond = cond
	@then_list = then_list
	@else_list = else_list
      end

      attr_reader :cond
      attr_reader :then_list
      attr_reader :else_list

      def pipeout=(val)
	@pipeout = val
	@then_list.last.pipeout = val if @then_list
	@else_list.last.pipeout = val if @else_list
      end

      def_accept
    end


    class WhileCommand<Command
      def_constructor

      def initialize(cond, node)
	@cond = cond
	@node = node
      end

      attr_reader :cond
      attr_reader :node

      def_accept
    end

    class UntilCommand<Command
      def_constructor

      def initialize(cond, node)
	@cond = cond
	@node = node
      end

      attr_reader :cond
      attr_reader :node

      def_accept
    end

    class ForCommand<Command
      def_constructor

      def initialize(vars, enum, seq)
	@vars = vars
	@enum = enum
	@seq = seq
      end

      attr_reader :vars
      attr_reader :enum
      attr_reader :seq

      def_accept
    end

    class CaseCommand<Command
      def_constructor

      def initialize(cond, body)
	@cond = cond
	@body = body
      end

      attr_reader :cond
      attr_reader :body

      def_accept
    end

    class WhenCommand<Command
      def_constructor

      def initialize(cond, seq)
	@cond = cond
	@seq = seq
      end

      attr_reader :cond
      attr_reader :seq

      def_accept
    end

    class BreakCommand<Command
      def_constructor

      def initialize(args)
	@args=args
	@pipepout = :NONE
      end

      attr_reader :args

      def pipeout=(val)
	#ignore
      end

      def_accept
    end


    class NextCommand<Command
      def_constructor

      def initialize(args)
	@args=args
	@pipepout = :NONE
      end

      attr_reader :args

      def pipeout=(val)
	#ignore
      end

      def_accept
    end

    class RedoCommand<Command
      def_constructor

      def initialize
	@pipepout = :NONE
      end
      def pipeout=(val)
	#ignore
      end

      def_accept
    end

    class RaieCommand<Command
      def_constructor

      def initialize(args)
	@args=args
	@pipepout = :NONE
      end

      attr_reader :args

      def pipeout=(val)
	#ignore
      end

      def_accept
    end

    class ReturnCommand<Command
      def_constructor

      def initialize(args)
	@args=args
	@pipepout = :NONE
      end

      attr_reader :args

      def pipeout=(val)
	#ignore
      end

      def_accept
    end

    class YieldCommand<Command
      def_constructor

      def initialize(args)
	@args=args
	@pipepout = :NONE
      end

      attr_reader :args

      def pipeout=(val)
	#ignore
      end

      def_accept
    end

    class ModIfCommand<Command
      def_constructor

      def initialize(com, cond)
	@com = com
	@cond = cond
      end

      attr_reader :com
      attr_reader :cond

      def_accept
    end

    class ModUnlessCommand<Command
      def_constructor

      def initialize(com, cond)
	@com = com
	@cond = cond
      end

      attr_reader :cond
      attr_reader :com

      def_accept
    end

    class ModWhileCommand<Command
      def_constructor

      def initialize(com, cond)
	@com = com
	@cond = cond
      end

      attr_reader :cond
      attr_reader :com

      def_accept
    end

    class ModUntilCommand<Command
      def_constructor

      def initialize(com, cond)
	@com = com
	@cond = cond
      end

      attr_reader :cond
      attr_reader :com

      def_accept
    end

    class ModRescueCommand<Command
      def_constructor

      def initialize(com, args)
	@com = com
	@args = args
      end

      attr_reader :com
      attr_reader :args

      def_accept
    end

    class Group<Command
      def_constructor

      def initialize(node)
	super()
	@nodes = node.nodes
      end
      
      attr_reader :nodes

      def pipeout=(val)
	@pipeout = val
	@nodes.last.pipeout = val
      end

      def_accept
    end

    class XString<Command
      def_constructor

      def initialize(node)
	super()
	@nodes = node.nodes
	nodes.each{|n| n.pipeout = :NONE}
      end
      
      attr_reader :nodes

      def pipeout=(val)
	@pipeout = val
#	@nodes.each{|n| n.pipeout = val}
      end

      def_accept "xstring"
    end

    class Sequence<Command
      def_constructor

      def initialize(com=nil)
	super()
	@nodes = []
	@nodes.push com if com
      end

      def pipeout=(val)
	@pipeout = val
	
	@nodes.each{|com| com.pipeout=val}
      end

      def add_command(com)
	@nodes.push com
      end

      attr_reader :nodes

      def last
	@nodes[-1]
      end

      def last_command_to_async
	@nodes[-1] = Node::AsyncCommand(@nodes[-1])
      end

      def_accept
    end

    class AsyncCommand<Node
      def_constructor

      def initialize(com)
	super()
	
	@subcommand = com
      end

      attr_reader :subcommand

      def_accept
    end

    class LiteralCommand<Command
      def_constructor
      
      def initialize(value)
	@value = value
      end

      attr_reader :value

      def_accept
    end
      
    class SimpleCommand<Command
      def_constructor

      def initialize(name, elements, b = nil)
	@name = name
	@args = elements
	@block = b
	@pipeout = nil

	@have_redirection = nil

	@args.each do |arg| 
	  case arg
	  when Group
	    arg.pipeout = :RESULT
	  end
	end
      end

      attr_reader :name
      attr_reader :args
      attr_reader :block

      def have_redirection?
	if @have_redirection.nil?
	  @have_redirection = @args.any?{|e| e.kind_of?(Redirection)}
	end
	@have_redirection
      end

      def inspect
	if Reish::INSPECT_LEBEL < 2
	  if @block
	    "#<SimpleCommand:#{@name.inspect}@pipeout=#{@pipeout.inspect}(#{@args.inspect})#{@block.inspect}>"
	  else
	    "#<SimpleCommand:#{@name.inspect}@pipeout=#{@pipeout.inspect}(#{@args.inspect})>"
	  end
	else
	  super
	end
      end
      def_accept
    end

    class DoBlock<Node
      def_constructor

      def initialize(body, args = nil)
	@body = body
	@args = args
      end
      attr_reader :body
      attr_reader :args

      def inspect
	if Reish::INSPECT_LEBEL < 2
	  if @args
	    "#<DoBlock:|#{@args.inspect}| #{@body.inspect}>"
	  else
	    "#<DoBlock: #{@body.inspect}>"
	  end
	else
	  super
	end
      end
      def_accept
    end

    class Redirection<Node
      def_constructor
      
      def initialize(source, id, red, over=nil)
	@source = source
	@id = id
	@red = red
	@over = over
      end

      attr_reader :source
      attr_reader :id
      attr_reader :red
      attr_reader :over

      def_accept
    end
      
    class TestCommand<SimpleCommand
      def_constructor
      
      def inspect
	if Reish::INSPECT_LEBEL < 2
	  if @block
	    "#<TestCommand:#{@name.inspect}(#{@args.inspect})#{@block.inspect}>"
	  else
	    "#<TestCommand:#{@name.inspect}(#{@args.inspect})>"
	  end
	else
	  super
	end
      end
      def_accept
    end
		     
    class Array<Node
      def_constructor

      def initialize(elements)
	super()
	@elements = elements
      end
      
      attr_reader :elements

      def_accept
    end

    class Hash<Node
      def_constructor

      def initialize(elements)
	super()
	@elements = elements
      end
      
      attr_reader :elements

      def_accept
    end

    class Symbol<ValueNode
      def_constructor
      def_accept
    end

    class RubyExp<SingleNode
      def_constructor
      
      def exp
	@token.exp
      end

      def_accept
    end


    class EOFNode<Node;end
    EOF = EOFNode.new

    class NOPNode<Node
      def_constructor
      def_accept
    end
    NOP = NOPNode.new

  end

end

