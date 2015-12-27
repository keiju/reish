#
#   reish/token.rb - 
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

  Token2TokenID = {}
  
  class Token
    def initialize(lex, *opts)
      case lex.io
      when File
	@input_name = lex.io.path
      else
	@input_name = "(#{self.class.name})"
      end

      @lex = lex
      @seek = lex.prev_seek
      @line_no = lex.prev_line_no
      @char_no = lex.prev_char_no
      @space_seen = lex.space_seen
    end

    attr_reader :lex
#    attr_reader :io
#    attr_reader :seek
#    attr_reader :line_no
#    attr_reader :char_no
    attr_reader :space_seen

    alias space_seen? space_seen

    def token_id
      Token2TokenID[self.class]
    end
  end

  class RubyExpToken<Token
    def initialize(lex, exp)
      super
      @exp = exp
    end
    
    attr_reader :exp

  end

  class CommandToken<Token
    def initialize(lex, name)
      super
      @name = name
    end
  end

  class ValueToken<Token
    def initialize(lex, val)
      super
      @value = val
    end
    attr_reader :value

    def inspect_tag
      self.class.name
    end

    def inspect
      if Reish::INSPECT_LEBEL < 3
	"#<#{inspect_tag}:#{@value.inspect}, l=#{@line_no}, c=#{@char_no}>"
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

  class TestToken<ValueToken
    def accept(visitor)
      visitor.visit_test(self)
    end

    def inspect_tag
      "TEST"
    end
  end

  class SpecialToken<ValueToken
    def accept(visitor)
      visitor.visit_test(self)
    end

    def inspect_tag
      "Special"
    end
  end

  class PathToken<ValueToken
    def accept(visitor)
      visitor.visit_path(self)
    end

    def inspect_tag
      "Path"
    end
  end

  class WordToken<ValueToken
    def accept(visitor)
      visitor.visit_word(self)
    end

    def inspect_tag
      "WORD"
    end
  end

  class WildCardToken<ValueToken
    def accept(visitor)
      visitor.visit_wildcard(self)
    end

    def inspect_tag
      "WCARD"
    end
  end

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

  class FidToken<ValueToken
    def accept(visitor)
      visitor.visit_fid(self)
    end

    def inspect_tag
      "FID"
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
      if Reish::INSPECT_LEBEL < 3
	"#<Token:#{@tid}, l=#{@line_no}, c=#{@char_no}>"
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
  end

  class SpaceToken<Token; end
  class EOFToken<Token; end
  class ErrorToken<Token; end

  DirectlyTokenIDClasses = [
    RubyExpToken,
    CommandToken,
    VariableToken,
    PseudoVariableToken,
    IDToken,
    TestToken,
    SpecialToken,
    PathToken,
    WordToken,
    WildCardToken,
    StringToken,
    RegexpToken,
    NumberToken,
    IntegerToken,
    FidToken,
    EOFToken,
  ]
  for c in DirectlyTokenIDClasses
    /::([^:]+)Token$/=~c.name 
    Token2TokenID[c] = $1.upcase.intern
  end

end

