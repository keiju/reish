#
#   reish/node.rb - 
#   	Copyright (C) 2014-2010 Keiju ISHITSUKA
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

	@space_seen = @value.space_seen

      end

      attr_reader :value

      attr_accessor :space_seen
      alias space_seen? space_seen

    end

    class SingleNode<Node
      def initialize(token)
	@token = token
	@space_seen = @token.space_seen
      end
      attr_reader :token

      attr_accessor :space_seen
      alias space_seen? space_seen
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

	@space_seen = nil
      end

      attr_accessor :pipein
      attr_accessor :pipeout

      attr_accessor :space_seen
      alias space_seen? space_seen
    end

    class LogicalCommand<Node
      def_constructor

      def initialize(com1, com2, op)
	@first = com1
	@second = com2
	@connector = op

	@space_seen = @first.space_seen
      end

      attr_reader :first
      attr_reader :second
      attr_reader :op

      attr_accessor :space_seen
      alias space_seen? space_seen

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

	@space_seen = com.space_seen
      end
      attr_reader :commands

      def pipeout=(val)
	@pipeout = val
	@commands.last.pipeout = val
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

	@variable.pipeout=:NONE

	begin
	  @value.pipeout=:RESULT
	rescue Exception
	  #literalの時
	end

	@space_seen = @variable.space_seen
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

	@space_seen = @variable.space_seen
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

	@space_seen = @variable.space_seen
      end

      attr_reader :variable
      attr_reader :index

      def_accept
    end

    class DefCommand<Command
      def_constructor

      def initialize(id, args, body)
	@id = id
	@args = args
	@body = body
      end

      attr_reader :id
      attr_reader :args
      attr_reader :body

      def_accept
    end

    class AliasCommand<Command
      def_constructor

      def initialize(id, pipeline)
	@id = id
	@pipeline = pipeline
      end

      attr_reader :id
      attr_reader :pipeline

      def_accept
    end

    class BeginCommand<Command
      def_constructor
      
      def initialize(seq, res, els, ens)
	@seq = seq
	@res = res
	@els = els
	@ens = ens

#	@seq.pipeout= :XNULL
#	@seq.last.pipeout= nil
      end

      attr_reader :seq
      attr_reader :res
      attr_reader :els
      attr_reader :ens

      def pipeout=(val)
	@pipeout = val

	@seq.pipeout= val
	case val
	when :BAR, :COLON2, :BAR_AND, :DOT, :RESULT, :XNULL, :NONE, :RESULTL
	  @res.each{|r| r.pipeout = :XNULL} if @res
	  @els.pipeout = :XNULL if @els
	  @ens.pipeout = :XNULL if @ens
	when nil
	  @seq.last.pipeout = nil
	  @res.each{|r| r.pipeout = nil} if @res
	  @els.pipeout = nil if @els
	  @ens.pipeout = nil if @ens
	end
      end

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

      def pipeout=(val)
	@seq.pipeout = val
      end

      def_accept
    end
      

    class IfCommand<Command
      def_constructor

      def initialize(cond, then_list=nil, else_list=nil)
	@cond = cond
	@cond.pipeout = :XNULL
	@then_list = then_list
	@else_list = else_list
      end

      attr_reader :cond
      attr_reader :then_list
      attr_reader :else_list

      def pipeout=(val)
	@pipeout = val
	@then_list.pipeout = val if @then_list
	@else_list.pipeout = val if @else_list
      end

      def_accept
    end


    class WhileCommand<Command
      def_constructor

      def initialize(cond, node)
	@cond = cond
	@cond.pipeout = :XNULL
	@node = node
      end

      attr_reader :cond
      attr_reader :node

      def pipeout=(val)
	@pipeout = val
	@node.pipeout = val
      end

      def_accept
    end

    class UntilCommand<Command
      def_constructor

      def initialize(cond, node)
	@cond = cond
	@cond.pipeout = :XNULL
	@node = node
      end

      attr_reader :cond
      attr_reader :node

      def pipeout=(val)
	@pipeout = val
	@node.pipeout = val
      end

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

      def pipeout=(val)
	@pipeout = val
	@seq.pipeout = val
      end

      def_accept
    end

    class CaseCommand<Command
      def_constructor

      def initialize(cond, body)
	@cond = cond
	@cond.pipeout = :XNULL
	@body = body
      end

      attr_reader :cond
      attr_reader :body

      def pipeout=(val)
	@pipeout = val
	@body.each{|w| w.pipeout=val}
      end

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

      def pipeout=(val)
	@pipeout = val
	@seq.pipeout = val
      end

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

    class RaiseCommand<Command
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
	@cond.pipeout = :XNULL
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
	@cond.pipeout = :XNULL
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
	@cond.pipeout = :XNULL
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
	@cond.pipeout = :XNULL
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
#	@nodes[0..-2].each{|n| n.pipeout = :XNULL}

	@space_seen = !@nodes.empty? && @nodes.first.space_seen
      end
      
      attr_reader :nodes

      def pipeout=(val)
	@pipeout = val
	case val
	when :BAR, :COLON2, :BAR_AND, :DOT
	  @nodes[0..-2].each{|n| n.pipeout = :XNULL}
	  @nodes.last.pipeout = :RESULT
	when :XNULL
	  @nodes.each{|n| n.pipeout = :XNULL}
	when :NONE, :RESULT, :RESULTL
	  @nodes[0..-2].each{|n| n.pipeout = :XNULL}
	  @nodes.last.pipeout = val
	when nil
	  @nodes.last.pipeout = nil
	end
      end

      def_accept
    end

    class XString<Command
      def_constructor

      def initialize(node)
	super()
	@nodes = node.nodes
	@nodes.each{|n| n.pipeout = :RESULT}

	@space_seen = @nodes.first.space_seen
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

	if com
	  @nodes.push com
	  @space_seen = com.space_seen
	end
      end

      def pipeout=(val)
	@pipeout = val
	
	case val
	when :RESULT, :RESULTL
	  @nodes[0..-2].each{|n| n.pipeout = :XNULL}
	  @nodes.last.pipeout = val
	when :BAR, :COLON2, :BAR_AND, :DOT, :NONE
	  @nodes[0..-2].each{|n| n.pipeout = :XNULL}
	  @nodes.last.pipeout = :NONE
	when :XNULL, nil
	  @nodes.each{|n| n.pipeout = val}
	end
      end

      def add_command(com)
	@space_seen = com.space_seen if @nodes.empty?
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

    class AsyncCommand<Command
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

	@space_seen = value.space_seen
      end

      attr_reader :value

      def_accept
    end
      
    class SimpleCommand<Command
      def_constructor

      def initialize(name, elements=nil, b = nil)
	@name = name
	@args = elements
	@block = b
	@pipeout = nil

	@have_redirection = nil

	if @args 
	  @args.each_compose do |arg| 
	    case arg
	    when Group
	      arg.pipeout = :RESULT
	    end
	  end
	end

	@space_seen = name.space_seen
      end

      attr_reader :name
      attr_reader :args
      attr_accessor :block

      def set_args(elements)
	@args = elements

	@args.each_compose do |arg| 
	  case arg
	  when Group
	    arg.pipeout = :RESULT
	  end
	end
      end

      def have_redirection?
	if @have_redirection.nil?
	  @have_redirection = @args && @args.any?{|e| e.kind_of?(Redirection)}
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

    class Redirector<Command
      def_constructor

      def initialize(node, reds)
	@node = node
	@node.pipeout = :RESULT
	@reds = reds
      end

      attr_reader :node
      attr_reader :reds

      def_accept
    end

    class Redirection<Node
      def_constructor
      
      def initialize(source, id, red, over=nil)
	@source = source
	@id = id
	@red = red
	@over = over

	@redirection
      end

      attr_reader :source
      attr_reader :id
      attr_reader :red
      attr_reader :over

      attr_accessor :space_seen
      alias space_seen? space_seen

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

	@space_seen = @elements.first.space_seen
      end

      attr_reader :elements

      attr_accessor :space_seen
      alias space_seen? space_seen

      def_accept
    end

    class Hash<Node
      def_constructor

      def initialize(elements)
	super()
	@elements = elements

	@space_seen = @elements.first.first.space_seen
      end
      
      attr_reader :elements

      attr_accessor :space_seen
      alias space_seen? space_seen

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


    class CommandElementList<Node
      include Enumerable

      def_constructor
      
      def initialize(elements = nil)
	super()
	case elements
	when nil
	  @elements = []
	when ::Array
	  @elements = elements
	  @space_seen = @elements.first.space_seen
	else
	  @elements = [elements]
	  @space_seen = elements.space_seen
	end

	@size = nil
	@lparen = nil
      end

      attr_reader :elements

      attr_accessor :space_seen
      alias space_seen? space_seen

      attr_accessor :lparen

      def empty?
	@elements.empty?
      end

      def size
	@size if @size
	
	s = 0
	each{s += 1}
	@size = s
      end

      def each_compose(&block)
	return if @elements.empty?
	prev = []
	@elements.each do |e|
	  if !e.space_seen?
	    prev.push e
	  else
	    if prev.size > 1
	      block.call CompositeWord.new(prev)
	    elsif prev.size == 1
	      block.call prev[0]
	    end
	    prev = [e]
	  end
	end
	if prev.size > 1
	  block.call CompositeWord.new(prev)
	else
	  block.call prev[0]
	end
      end

      alias each each_compose

      def composed_words
	each_compose.to_a
      end

      def push(elm)
	@space_seen = elm.space_seen if @elements.empty?
	@elements.push elm
      end
      
      def_accept
    end
		
    class CompositeWord<Node
      def_constructor

      def initialize(els)
	super()
	@elements = els
      end
      
      attr_reader :elements

#      def push(e)
#	@elements.push e
#      end

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

