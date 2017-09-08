#
#   compspec.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)

require "reish/comp-module-spec"

module Reish

  def Reish::CompSpec(receiver, name)
    CompSpec.spec(receiver, name)
  end

  class CompSpec

    N2Spec = {}
    M2Spec = {}

    def CompSpec.def_command(name, spec)
      N2Spec[name] = spec
    end

    def CompSpec.def_method(klass, name, spec)
      M2Spec[[klass, name]] = spec
    end

    def CompSpec.spec(receiver, name)
puts "CS#0"
p receiver
p name
      unless  /^\// =~ name
	case receiver
	when ModuleSpec, DescendantSpec
puts "CS#1"

	  mod = receiver.module
p mod
	  spec = nil
	  mod.ancestors.find{|m| spec = M2Spec[[m, name]]}
p spec
	  if !spec && receiver.respond_to?(name)
	    spec = DefaultRubyMethodCS
	  end
	  return spec
	when CompositeSpec
puts "CS#2"
	  specs = Set.new
	  receiver.modules.each do |mod|
	    spec = nil
	    mod.ancestors.find{|m| spec = M2Spec[[m, name]]}
	    if !spec && receiver.respond_to?(name)
	      spec = DefaultRubyMethodCS
	    end
	    specs<<spec
	  end
	  return specs
	else
puts "CS#3"
	  for mod in receiver.class.ancestors
	    spec = M2Spec[[mod, name]]
	    if spec
	      puts "Match CompSpec for #{mod}##{name} spec: #{spec.inspect}"
	      return spec
	    end
	  end
	  return DefaultRubyMethodCS if receiver.respond_to?(name)
	end
      end
      spec = N2Spec[name]
puts "CS#4"
      return spec if spec
puts "CS#5"
      DefaultSystemCommandCS
    end


    def initialize
      @arg_proc = nil
      @ret_proc = nil
    end
    
    attr_accessor :arg_proc
    attr_accessor :ret_proc
    
    def arg_candidates(call)
      return @arg_proc.call call if @arg_proc
      []
    end

    def return_value(call)
      return @ret_proc.call call if @ret_proc
      Reish::DescendantSpec(Object)
    end

    def objects(call, filer=nil)
      []
    end

    def objects_arg_proc
      proc{|call| objects(call)}
    end

    
    # filter: nil 指定なし, true 
    def files(call, filter=nil)
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
	l = pwd.size
	Dir.glob("#{pwd}/#{arg}*", File::FNM_DOTMATCH).collect{|e| e[0..l]= ""; e}
      else
	Dir.entries(pwd).select{|e| /^\./ !~ e}
      end
    end
    
    def files_arg_proc
      proc{|call| files(call)}
    end

    def options(call, filter=nil, sopt = nil, lopts = [])

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

    def commands(call, filter=nil)
      exenv = eval("@exenv", call.bind)
      shell = exenv.shell
      filter shell.all_commands, call, filter
    end

    def command_arg_proc
      proc{|call| commands(call)}
    end
    
    def command_ret_proc
      proc{|call| Reish::ModuleSpec(SystemCommand)}
    end

    def symbols(call, filter=nil)
      filter Symbol.all_symbols.collect{|s| ":" + s.id2name}, call, filter
    end

    def symbols_arg_proc
      proc{|call| symbols(call)}
    end

    def filter(candidates, call, filter=nil)

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
  end

  class CompositeCompSpec
    def initialize
      @specs = Set.new
    end

    def <<(spec)
      @specs<<spec
    end

    def return_value
      @specs.inject{|ret, spec| ret |= spec.return_value}
    end
  end

  DefaultRubyMethodCS = CompSpec.new
  DefaultRubyMethodCS.arg_proc = DefaultRubyMethodCS.objects_arg_proc
  DefaultRubyMethodCS.ret_proc = proc{|call| DescendantSpec(Object)}

  DefaultNewCS = CompSpec.new
  DefaultNewCS.arg_proc = DefaultRubyMethodCS.objects_arg_proc
  DefaultNewCS.ret_proc = proc{|call| 
    rec = call.receiver
    case rec
    when Class
      ModuleSpec(rec)
    when ModuleSpec, DescendantSpec, CompositeSpec
      rec
    else
      raise "not implemented for: #{rec.inspect}"
    end
  }
  CompSpec.def_method(Class, "new", DefaultNewCS)

  DefaultSystemCommandCS = CompSpec.new
  DefaultSystemCommandCS.arg_proc = DefaultSystemCommandCS.files_arg_proc
  DefaultSystemCommandCS.ret_proc = proc{|call| ModuleSpec(SystemCommand)}

  CompSpec.def_method Object, "Special#|", DefaultRubyMethodCS
  CompSpec.def_method Object, "Special#&", DefaultRubyMethodCS
  CompSpec.def_method Object, "Special#&&", DefaultRubyMethodCS
  CompSpec.def_method Object, "Special#||", DefaultRubyMethodCS
  CompSpec.def_method Object, "Special#-", DefaultRubyMethodCS
  CompSpec.def_method Object, "Special#+", DefaultRubyMethodCS
  CompSpec.def_method Object, "Special#/", DefaultRubyMethodCS
  CompSpec.def_method Object, "Special#*", DefaultRubyMethodCS
  CompSpec.def_method Object, "Special#>=", DefaultRubyMethodCS
  CompSpec.def_method Object, "Special#<=", DefaultRubyMethodCS
  CompSpec.def_method Object, "Special#==", DefaultRubyMethodCS
  CompSpec.def_method Object, "Special#<=>", DefaultRubyMethodCS
  CompSpec.def_method Object, "Special#=~", DefaultRubyMethodCS
  CompSpec.def_method Object, "Special#!~", DefaultRubyMethodCS

  CompSpec.def_method Object, "RESERVED#=", DefaultSystemCommandCS

  command_arg_cs = CompSpec.new
  command_arg_cs.arg_proc = command_arg_cs.command_arg_proc
  command_arg_cs.ret_proc = proc{|call| Object}
  CompSpec.def_method Object, "RESERVED#BANG", command_arg_cs
  CompSpec.def_method Object, "RESERVED#|", command_arg_cs

  symbols_arg_cs = CompSpec.new
  symbols_arg_cs.arg_proc = symbols_arg_cs.symbols_arg_proc
  symbols_arg_cs.ret_proc = proc{|call| Object}
  CompSpec.def_method Object, "RESERVED#SYMBEG", symbols_arg_cs

  CompSpec.def_method Object, "RESERVED#COLON2", command_arg_cs

  # 未実装 :MOD_IF, :MOD_UNLESS, :MOD_WHILE, :MOD_UNTIL,  :MOD_RESCUE

  CompSpec.def_method Object, "RESERVED#>", DefaultSystemCommandCS
  CompSpec.def_method Object, "RESERVED#<", DefaultSystemCommandCS
  CompSpec.def_method Object, "RESERVED#GREATER_GREATER", DefaultSystemCommandCS
  CompSpec.def_method Object, "RESERVED#GREATER_BAR", DefaultSystemCommandCS
  CompSpec.def_method Object, "RESERVED#LESS_GREATER", DefaultSystemCommandCS
  CompSpec.def_method Object, "RESERVED#LESS_LESS", DefaultSystemCommandCS
  CompSpec.def_method Object, "RESERVED#LESS_LESS_MINUS", DefaultSystemCommandCS
  CompSpec.def_method Object, "RESERVED#LESS_LESS_LESS", DefaultSystemCommandCS
  CompSpec.def_method Object, "RESERVED#LESS_AND", DefaultSystemCommandCS
  CompSpec.def_method Object, "RESERVED#GREATER_AND", DefaultSystemCommandCS
  CompSpec.def_method Object, "RESERVED#AND_GREATER", DefaultSystemCommandCS
  CompSpec.def_method Object, "RESERVED#AND_GREATER_GREATER", DefaultSystemCommandCS

  (class<<Test; TestTestMap.keys; end).each do |sub|
    CompSpec.def_method Object, "TEST#"+sub, DefaultSystemCommandCS
  end
  #例外: -owner? fn user 

  cs_grep = CompSpec.new
  cs_grep.arg_proc = cs_grep.objects_arg_proc
  cs_grep.ret_proc = proc{|call| ModuleSpec(Array)}
  CompSpec.def_method(Enumerable, "grep", cs_grep)

  # ls補完のサンプル
  cs_ls = CompSpec.new
  cs_ls.arg_proc = proc{|call|
    if call.last_arg
      case call.last_arg.value
      when /^-/
	cs_ls.options(call, nil, "aAbBcCdDfFgGgGikILmnNopqQrRsStTuUvwxXZ1", 
		      ["--all", "--almost-all", "--author", "--escape", "--block-size", "--ignore-backups", "--color", "--directory", "--dired", "--classify", "--file-type", "--format=WORD", "--full-time", "--group-directories-first", "--no-group", "--human-readable", "--dereference-command-line", "--dereference-command-line-symlink-to-dir", "--hide", "--indicator-style", "--inode", "--ignore", "--kibibytes", "--dereference", "--numeric-uid-gid", "--literal", "--indicator-style", "--hide-control-chars", "--show-control-chars", "--quote-name", "--quoting-style", "--reverse", "--recursive", "--size", "--sort", "--time", "--time-style", "--tabsize", "--width", "--context", "--help", "--version"])
      else
	cs_ls.files(call)
      end
    else
      cs_ls.files(call)
    end
  }
  cs_ls.ret_proc = cs_ls.command_ret_proc
  CompSpec.def_command "ls", cs_ls

  cs_grep = CompSpec.new
  cs_grep.arg_proc = proc{|call|
    if call.last_arg
      case call.last_arg.value
      when /^-/
	cs_grep.options(call, nil, "",
			["--extended-regexp", "--fixed-strings", "--basic-regexp", "--perl-regexp", "--regexp", "--file", "--ignore-case", "--word-regexp", "--line-regexp", "--null-data", "--no-messages", "--invert-match", "--version", "--help", "--max-count=NUM", "--byte-offset", "--line-number", "--line-buffered", "--with-filename", "--no-filename", "--label=LABEL", "--only-matching", "--quiet", "--silent", "--binary-files", "--text", "--directories", "--devices", "--recursive", "--dereference-recursive", "--include", "--exclude", "--exclude-from", "--exclude-dir", "--files-without-match", "--files-with-matches", "--count", "--initial-tab", "--null", "--before-context", "--after-context", "--context", "--color", "--colour", "--binary", "--unix-byte-offsets"])
      else
	cs_grep.files(call)
      end
    else
      cs_grep.files(call)
    end
  }
  CompSpec.def_command "/grep", cs_grep

end

