#
#   node.rb - 
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

      p "def accept(v); v.visit_#{n}(self)"

      class_eval "def accept(v); v.visit_#{n}(self); end"
    end


    class ValueNode<Node
      def initialize(val)
	super
	@value = val
      end
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

    class WhileCommand<Node
      def_constructor

      def initialize(cond, node)
	@cond = cond
	@node = node
      end

      attr_reader :cond
      attr_reader :node

      def_accept
    end

    class IfCommand<Node
      def_constructor

      def initialize(cond, then_list=nil, else_list=nil)
	@cond = cond
	@then_list = then_list
	@else_list = else_list
      end

      attr_reader :cond
      attr_reader :then_list
      attr_reader :else_list

      def_accept
    end

    class Group<Node
      def_constructor

      def initialize(node)
	super()
	@node = node
      end
      
      attr_reader :node

      def_accept
    end

    class SeqCommand<Node
      def_constructor

      def initialize(com=nil)
	super()
	@nodes = []
	@nodes.push com if com
      end

      def add_command(com)
	@nodes.push com
      end

      attr_reader :nodes

      def last_command_to_async
	@nodes[-1] = Node::AsyncCommand(@nodes[-1])
      end

      def_accept
    end

    class ConnectCommand<Node
      def_constructor

      def initialize(com1, com2, connector)
	@first = com1
	@second = com2
	@connector = connector
      end

      attr_reader :first
      attr_reader :second
      attr_reader :connector

      def_accept
    end

    class ConnectCommandAA<ConnectCommand
      def_constructor

      def initialize(com1, com2)
	super com1, com2, "&&"
      end

      def_accept "connect_command_aa"
    end

    class ConnectCommandOO<ConnectCommand
      def_constructor

      def initialize(com1, com2=nil)
	super com1, com2, "||"
      end

      def_accept "connect_command_oo"
    end

    class ConnectCommandBAR<ConnectCommand
      def_constructor

      def initialize(com1, com2=nil)
	super com1, com2, "|"
      end

      def_accept  "connect_command_bar"
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

    class SimpleCommand<Node
      def_constructor

      def initialize(name, elements, b = nil)
	@name = name
	@args = elements
	@block = b
      end

      attr_reader :name
      attr_reader :args
      attr_reader :block

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

