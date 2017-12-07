#
#   comp-exec.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
module Reish
  module CompAction
    def ca_commands(call, filter=nil)
      exenv = eval("@exenv", call.bind)
      shell = exenv.shell
      filter shell.all_commands, call, filter
    end
    alias commands ca_commands

    # filter: nil 指定なし, true 
    def ca_files(call, filter=nil)
      exenv = eval("@exenv", call.bind)
      if exenv
	pwd = exenv.pwd
      else
	pwd = Dir.pwd
      end

      if filter
	arg = filter
      elsif call.last_arg
	arg = call.last_arg.value
      else
	arg = nil
      end

      if arg
	if /^\// === arg
	  pwd = ""
	end

	l = pwd.size
	Dir.glob("#{pwd}/#{arg}*", File::FNM_DOTMATCH).collect{|e| e[0..l]= ""; e}
      else
	Dir.entries(pwd).select{|e| /^\./ !~ e}
      end
    end
    alias files ca_files

    def ca_filter(candidates, call, filter=nil)

      if filter
	arg = filter
      elsif call.last_arg
	arg = call.last_arg.value
      else 
	arg = nil
      end

      if arg
	candidates.select{|c| c[0..arg.size-1] == arg}
      else
	candidates
      end
    end
    alias filter ca_filter

    def ca_options(call, filter=nil, sopt = nil, lopts = [])

# short opt も補完候補にする場合
#      opts = sopt.split(//).collect{|c| "-" + c}
#      opts.concat lopts

      if filter && filter == "-" || call.last_arg && call.last_arg.value == "-"
# short opy を表示のみする場合(表示はいまいち)
#	puts "","-"+sopt
	return ["-"]
      end
      filter(lopts, call, filter)
    end
    alias options ca_options
  end
end
