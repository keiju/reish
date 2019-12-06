#
#   rei.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#
require "rei/conf.rb"
require "rei/core.rb"
require "rei/basic-shell.rb"

module REI

  Reicore = Core.new

  DefaultEncodings = Struct.new(:external, :internal)
  class << REI
    private
    def set_encoding(extern, intern = nil)
      verbose, $VERBOSE = $VERBOSE, nil
      Encoding.default_external = extern unless extern.nil? || extern.empty?
      Encoding.default_internal = intern unless intern.nil? || intern.empty?
      @CONF[:ENCODINGS] = Rei::DefaultEncodings.new(extern, intern)
      [$stdin, $stdout, $stderr].each do |io|
	io.set_encoding(extern, intern)
      end
      @CONF[:LC_MESSAGES].instance_variable_set(:@encoding, extern)
    ensure
      $VERBOSE = verbose
    end
  end

  def def_debug_functions(mod, debug_category)
    f = 1
    debug_category.each do |cat|
      c = "DEBUG_"+cat.id2name
      const_set(c, f)
      method_name = cat.id2name.downcase
      mod.module_eval(%{
        def debug_#{method_name}?
	    @CONF[:DEBUG] & #{c} != 0
        end
        def debug_#{method_name}_on
	    @CONF[:DEBUG] |= #{c}
        end
        def debug_#{method_name}_off
	    @CONF[:DEBUG] &= ~#{c}
        end
      })
      f<<=1
    end

    mod.module_eval{
      def debug?(flag = DEBUG_GENERAL)
        @CONF[:DEBUG] & flag != 0
      end
    }
  end

end


