n#
#   basic-shell.rb - 
#   	Copyright (C) 1996-2019 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

module REI
  class BasicShell

    def BasicShell::inherited(sub)
      sub.instance_eval do
        @CONF = Conf.new
        @COMP = {}
        @COMP[:INPUT_METHOD] = {}
      end
    end

    def BasicShell::start(ap_path = nil)
      $0 = File::basename(ap_path, ".rb") if ap_path
      setup(ap_path)

      sh = create_main_shell
      const_set(:MAIN_SHELL, sh)
      sh.start
    end

    #Shell.create_main_shell

    def BasicShell::setup(ap_path)
      init_core(ap_path)

      init_error
      init_config(ap_path)
      parse_opts
      run_config if @CONF[:RC]
    end

    def BasicShell::init_core(ap_path)
      @CORE = Core.new(ap_path)
      const_set(:CORE, @CORE)
    end

    def BasicShell.conf
      @CONF
    end

    def BasicShell.core_conf
      @CORE.conf
    end

    def BasicShell.comp
      @COMP
    end

  end
end


