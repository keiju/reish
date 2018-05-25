#
#   reirb/token.rb - 
#   	Copyright (C) 2014-2018 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

module Reirb

  Token2TokenID = {}

  class Token
    def initialize(lex, *opts)
#      case lex.io
#      when File
#	@input_name = lex.io.path
#      else
#	@input_name = "(#{self.class.name})"
#      end

      @lex = lex
#      @seek = lex.prev_seek
      @line_no = lex.prev_line_no
      @char_no = lex.prev_char_no
      @space_seen = lex.space_seen
      @state = lex.scanner.state

      @ltype = nil
    end

    attr_reader :lex
    attr_reader :io
#    attr_reader :seek
    attr_reader :line_no
    attr_reader :char_no
    attr_reader :space_seen
    attr_reader :state

    attr_accessor :ltype

    alias space_seen? space_seen

    def token_id
      Token2TokenID[self.class]
    end
  end

  class ValueToken<Token
    def self.dup_from(src, id)
      new_token = new(src.lex, id)
      new_token.instance_eval do
	@io = src.io
#	@seek = src.seek
	@line_no = src.line_no
	@char_no = src.char_no
	@space_seen = src.space_seen
      end
      new_token
    end

    def initialize(lex, val)
      super
      @value = val
    end
    attr_reader :value

    def inspect_tag
      self.class.name
    end

    def inspect
      if Reirb::INSPECT_LEBEL < 2
	"#<#{inspect_tag}:#{@value.inspect}: l=#{@line_no}, c=#{@char_no}, s=#{@state}>"
      elsif Reirb::INSPECT_LEBEL < 3
	"#<#{inspect_tag}:#{@value.inspect}: l=#{@line_no}, c=#{@char_no} space_seen=#{@space_seen}, s=#{@state}>"
      else
	super
      end
    end
  end

  class VariableToken<ValueToken
    def accept(visitor)
      visitor.visit_variable(self)
    end

    def inspect_tag
      "VAR"
    end
  end

  class PseudoVariableToken<ValueToken
    def accept(visitor)
      visitor.visit_pseudo_variable(self)
    end

    def inspect_tag
      "PVAR"
    end
  end

  class IDToken<ValueToken
    def accept(visitor)
      visitor.visit_id(self)
    end

    def inspect_tag
      "ID"
    end
  end

  class LiteralBegToken<ValueToken; end
  class LitreralEndToken<ValueToken; end

  class StringBegToken<LiteralBegToken; end
  class RegexpBegToken<LiteralBegToken; end
  class SymbegToken<LiteralBegToken; end
  class QSymbolsBegToken<LiteralBegToken; end
  class QWordsBegToken<LiteralBegToken; end

  class StringEndToken<LiteralBegToken; end
  class ReexpEndToken<LiteralBegToken; end

  class EmbexprBegToken<ValueToken; end

  class StringToken<ValueToken
    def accept(visitor)
      visitor.visit_string(self)
    end

    def inspect_tag
      "STR"
    end
  end

  class RegexpToken<ValueToken
    def accept(visitor)
      visitor.visit_regexp(self)
    end

    def inspect_tag
      "REG"
    end
  end

  class NumberToken<ValueToken
    def accept(visitor)
      visitor.visit_number(self)
    end

    def inspect_tag
      "NUM"
    end
  end

  class IntegerToken<ValueToken
    def accept(visitor)
      visitor.visit_integer(self)
    end

    def inspect_tag
      "INT"
    end
  end

  class ReservedWordToken<Token
    def initialize(lex, tid)
      super
      @tid = tid
    end

    def token_id
      @tid
    end

    def inspect
      if Reirb::INSPECT_LEBEL < 3
	"#<Token:#{@tid}: l=#{@line_no}, c=#{@char_no}, s=#{@state}>"
      else
	super
      end
    end
  end

  class SimpleToken<Token
    def initialize(lex, name)
      super
      @name = name
    end

    def token_id
      @name
    end

    def inspect
      if Reirb::INSPECT_LEBEL < 3
	"#<Token:#{@name}: l=#{@line_no}, c=#{@char_no}, s=#{@state}>"
      else
	super
      end
    end
  end

  class CommentToken<ValueToken
    def accept(visitor)
      visitor.visit_comment(self)
    end

    def inspect_tag
      "CMT"
    end
  end

  class SpaceToken<Token
    def inspect
      if Reirb::INSPECT_LEBEL < 3
	"#<SpaceToken:l=#{@line_no}, c=#{@char_no}, s=#{@state}>"
      else
	super
      end
    end
  end

  class IgnoreNLToken<Token; end

  class EOFToken<Token
    def inspect
      if Reirb::INSPECT_LEBEL < 3
	"#<EOFToken:l=#{@line_no}, c=#{@char_no}, s=#{@state}>"
      else
	super
      end
    end
  end

  class ErrorToken<Token
    def inspect
      if Reirb::INSPECT_LEBEL < 3
	"#<ErrorToken:l=#{@line_no}, c=#{@char_no}, s=#{@state}>"
      else
	super
      end
    end
  end

  DirectlyTokenIDClasses = [
    VariableToken,
    PseudoVariableToken,
    IDToken,
    StringToken,
    RegexpToken,
    NumberToken,
    IntegerToken,
    EOFToken,
  ]
  for c in DirectlyTokenIDClasses
    /::([^:]+)Token$/=~c.name 
    Token2TokenID[c] = $1.upcase.intern
  end

end

