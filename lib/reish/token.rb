#
#   token.rb - 
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
  end

  class IDToken<ValueToken

    def accept(visitor)
      visitor.visit_id(self)
    end
  end
  class WordToken<ValueToken
    def accept(visitor)
      visitor.visit_word(self)
    end
  end
  class StringToken<ValueToken; end
  class NumberToken<ValueToken; end

  class ReservedWordToken<Token
    def initialize(io, seek, line_no, char_no, tid)
      super
      @tid = tid
    end

    def token_id
      @tid
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
    WordToken,
    StringToken,
    NumberToken,
    EOFToken,
  ]
  for c in DirectlyTokenIDClasses
    /::([^:]+)Token$/=~c.name 
    Token2TokenID[c] = $1.upcase.intern
  end

end

