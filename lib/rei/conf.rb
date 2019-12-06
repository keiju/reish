# coding: utf-8
#
#   conf.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

module REI
  # CoreConf(Process毎), ShellConf(Shellクラス毎), shell_instance_conf(shellインスタンス毎)
  #
  class Conf
    Default = {
      AP_NAME: nil, #File::basename(ap_path, ".rb"),
      REI_LIB_PATH: [],
      RC: nil,
      RC_FILE: nil,
      RC_SCRIPT: nil,
      LOAD_MODULES: [],
      PROMPT: nil,
      SINGLE_SHELL: false,
      BINDING_MODE: 3,

      DISPLY_MODE: true,
      IGNORE_SIGINT: true,
      IGNORE_EOF: false,
      ECHO: nil,

      VERBOSE: nil,
      AT_EXIT: [],
      DEBUG: 0,
    }

    def initialize(super_conf = DefaultBaseConf)
      @super_conf = super_conf
      @conf = {}
    end

    def [](key)
      @conf[key] || (@super_conf && @super_conf[key])
    end

    def has_key?(key)
      @conf.has_key?(key) || (@super_conf && @super_conf.has_key?(key))
    end

    def []=(key, value)
      # if @super_conf&.has_key?(key)
      #   @super_conf[key] = value
      # else
      #   @conf[key] = value
      # end
      @conf[key] = value
    end

    def delete(key)
      @conf.delete(key)
    end

    def temp_key(prefix = "__REI__", postfix = "__", &block)
      begin
        s = Thread.current.__id__.to_s(16).tr("-", "M")
        key = (prefix+s+postfix).intern
        while has_key?(key)
          n = (n || 1) + 1
          key = "#{prefix}{s}_{n.to_i}_#{postfix}".intern
        end 
    
        block.call key
        ensure
          delete(key)
      end
    end
  end

  class CoreConf<Conf
    def initialize(ap_path)
      super(nil)
      @conf.merge! Default
      @conf[:AP_NAME] = File::basename(ap_path, ".rb")
    end
  end
end
