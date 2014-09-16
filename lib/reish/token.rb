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

  EXPR_BEG = :EXPR_BEG
  EXPR_MID = :EXPR_MID
  EXPR_END = :EXPR_END
  EXPR_ARG = :EXPR_ARG
  EXPR_FNAME = :EXPR_FNAME
  EXPR_DOT = :EXPR_DOT
  EXPR_CLASS = :EXPR_CLASS

  Token2TokenID = {}
  
  class Token
    def initialize(io, seek, line_no, char_no, *opts)
      case io
      when File
	@input_name = io.path
      else
	@input_name = "(#{self.class.name})"
      end

      @seek = seek
      @line_no = line_no
      @char_no = char_no
    end

    def token_id
      Token2TokenID[self.class]
    end
  end

  class RubyExpToken<Token
    def initialize(io, seek, line_no, char_no, exp)
      super
      @exp = exp
    end
    
    attr_reader :exp

  end

  class CommandToken<Token
    def initialize(io, seek, line_no, char_no, name)
      super
      @name = name
    end
  end

  class ValueToken<Token
    def initialize(io, seek, line_no, char_no, val)
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

  class IDToken<ValueToken

    def accept(visitor)
      visitor.visit_id(self)
    end

    def inspect_tag
      "ID"
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
    def inspect_tag
      "STR"
    end
  end
  class NumberToken<ValueToken
    def inspect_tag
      "NUM"
    end
  end

  class ReservedWordToken<Token
    def initialize(io, seek, line_no, char_no, tid)
      super
      @tid = tid
    end

    def token_id
      @tid
    end

    def inspect
      if Reish::INSPECT_LEBEL < 3
	"#<Token#{@tid}, l=#{@line_no}, c=#{@char_no}>"
      else
	super
      end
    end
  end

  class SimpleToken<Token
    def initialize(io, seek, line_no, char_no, name)
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
    IDToken,
    PathToken,
    WordToken,
    WildCardToken,
    StringToken,
    NumberToken,
    EOFToken,
  ]
  for c in DirectlyTokenIDClasses
    /::([^:]+)Token$/=~c.name 
    Token2TokenID[c] = $1.upcase.intern
  end

end

