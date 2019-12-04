#
#   basic-shell.rb - 
#   	Copyright (C) 1996-2019 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

module Rei
  class BasicShell

    def BasicShell::inherited(sub)
      sub.instance_eval do
        @CONF = {}
        @COMP = {}
        @COMP[:INPUT_METHOD] = {}
      end
    end

    def BasicShell::start(ap_path = nil)
      $0 = File::basename(ap_path, ".rb") if ap_path
      setup(ap_path)

      if @CONF[:OPT_C]
        im = self::StringInputMethod.new(nil, @CONF[:OPT_C])
        sh = self::MainShell.new(im)
      elsif @CONF[:OPT_TEST_CMPL]
        compl = @COMP[:COMPLETOR].new(new)
        compl.candidate(@CONF[:OPT_TEST_CMPL])
        exit
      elsif !ARGV.empty?
        f = ARGV.shift
        sh = self::MainShell.new(f)
      else
        sh = self::MainShell.new
      end
      const_set(:MAIN_SHELL, sh)

      sh.start
    end
  end
end


