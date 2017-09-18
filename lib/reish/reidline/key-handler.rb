#
#   key-handler.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "io/console"

module Reish
  class Reidline
    class KeyHandler
      
      def initialize(&block)
	@head = Node.new
	@handler = block
      end

      def def_key(key, method_id = nil, &block)
	case method_id
	when Proc, Method
	  block = method_id
	end
	
	@head.place key.chars, Node.new(key, &block)
      end

      def def_keys(*keys, &block)
	for key in keys
	  def_key(key, &block)
	end
      end

      def def_handlers(definitions)
	definitions.each do |key, method_id|
	  def_key key, method_id
	end
      end

      def def_default(method_id = nil, &block)
	case method_id
	when Proc, Method
	  block = method_id
	end

	@handler = block
      end
      
      def dispatch(io)
	node = nil
	STDIN.noecho do
	  STDIN.raw do
	    node = @head.match(io)
	  end
	end

	case node
	when Node
	  node.handler.call(io, node.key)
	else
	  @handler.call(io, node.join)
	end
      end
      
#    def inspect
#      format("<SLex: @head = %s>", @head.inspect)
#    end

      class Node
	def initialize(key = nil, &block)
	  @key = key
	  @nodes = {}
	  @handler = block
	end

	attr_reader :key
	attr_reader :handler

	def leaf?
	  @nodes.empty?
	end

	def place(chrs, leaf)

	  ch = chrs.shift
	  if node = @nodes[ch]
	    if chrs.empty?
	      raise ArgumentError, "ノード定義が重複しています"
	    else
	      node.place(chrs, leaf)
	    end
	  else
	    if chrs.empty?
	      node = leaf
	    else
	      node = Node.new
	      node.place chrs, leaf
	    end
	    @nodes[ch] = node
	  end
	  node
	end

	def match(io, op = [])
	  ch = io.getc
	  if ch.nil?
	    return op 
	  end

	  op.push ch
	  if node = @nodes[ch]
	    if node.leaf?
	      node
	    else
	      node.match(io, op)
	    end
	  else
	    op
	  end
	end
      end
    end
  end
end

if $0 == __FILE__

require "pp"
  
  handler = Reish::Editor::KeyHandler.new
  handler.def_key("\e[A"){puts "UP"}
  handler.def_key("\e[C"){puts ">>"}
  handler.def_key("\e[B"){puts "DOWN"}
  handler.def_key("\e[D"){puts "<<"}

  handler.def_key("\e[3~"){puts "DEL"}
  handler.def_key("\e[5~"){puts "ROLL UP"}
  handler.def_key("\e[6~"){puts "ROLL DOWN"}

  handler.def_key("\r"){puts "CR"}
  

  handler.def_key("\u007F"){puts "BS"}
  handler.def_key("\b"){puts "^H"}
  handler.def_key("\u0003"){puts "^C"; exit}

  handler.def_key("exit"){puts "exit"; exit}


  handler.def_default do |io, ch|
    puts "DEF##{ch.inspect}"
  end

  STDIN.noecho do
    STDIN.raw do
      loop do
	handler.dispatch(STDIN)
      end
    end
  end
end
  
