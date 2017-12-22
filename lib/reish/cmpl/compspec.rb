#
#   compspec.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)

require "reish/cmpl/comp-module-spec"
require "reish/cmpl/comp-action"
require "reish/cmpl/comp-arg-proc"

module Reish

  def Reish::CompSpec(receiver, name)
    CompSpec.spec(receiver, name)
  end

  class CompSpec
    include CompAction

    N2Spec = {}
    M2Spec = {}

    def CompSpec.def_command(name, spec)
      N2Spec[name] = spec
    end

    def CompSpec.def_method(klass, name, spec)
      M2Spec[[klass, name]] = spec
    end

    def CompSpec.spec(receiver, name)
      unless  /^\// =~ name
	case receiver
	when ModuleSpec, DescendantSpec
	  mod = receiver.module
	  spec = nil
	  mod.ancestors.find{|m| spec = M2Spec[[m, name]]}
	  if !spec && receiver.respond_to?(name)
	    spec = DefaultRubyMethodCS
	  end
	  return spec if spec
	when CompositeSpec
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
	  case receiver
	  when Module
	    desc = receiver.singleton_class
	  else
	    desc = receiver.class
	  end
	  for mod in desc.ancestors
	    spec = M2Spec[[mod, name]]
	    if spec
	      puts "Match CompSpec for #{mod}##{name} spec: #{spec.inspect}" if Reish.debug_cmpl?
	      return spec
	    end
	  end
	  return DefaultRubyMethodCS if receiver.respond_to?(name)
	end
      end
      spec = N2Spec[name]
      return spec if spec
      DefaultSystemCommandCS
    end


    def initialize
      @arg_proc = nil
      @ret_proc = nil
    end
    
    attr_accessor :arg_proc
    attr_accessor :ret_proc

    def arg_proc(&block)
      @arg_proc = block
    end
    
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

    def command_arg_proc
      proc{|call| commands(call)}
    end
    
    def command_ret_proc
      proc{|call| Reish::ModuleSpec(Enumerator::Lazy)}
    end

    def symbols(call, filter=nil)
      filter Symbol.all_symbols.collect{|s| ":" + s.id2name}, call, filter
    end

    def symbols_arg_proc
      proc{|call| symbols(call)}
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
  
  FileNewCS = DefaultNewCS.clone
  FileNewCS.arg_proc = proc{|call| 
    if call.args.size == 0
      FileNewCS.files(call)
    end
  }
  FileNewCS.ret_proc{ModuleSpec(File)}
  CompSpec.def_method(File.singleton_class, "new", FileNewCS)
  CompSpec.def_method(File.singleton_class, "open", FileNewCS)

  DefaultSystemCommandCS = CompSpec.new
  DefaultSystemCommandCS.arg_proc = DefaultSystemCommandCS.files_arg_proc
  DefaultSystemCommandCS.ret_proc = proc{|call| ModuleSpec(SystemCommand)}

  all_cs = CompSpec.new
  all_cs.arg_proc = all_cs.objects_arg_proc
  all_cs.ret_proc = proc{|call| ModuleSpec(TrueClass) | ModuleSpec(FalseClass)}
  CompSpec.def_method(Enumerable, "all?", all_cs)
  CompSpec.def_method(Enumerable, "any?", all_cs)
  

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
  cs_grep.ret_proc = proc{|call| call.args.size == 0 ? ModuleSpec(Enumerator) : ModuleSpec(Array)}
  CompSpec.def_method(Enumerable, "grep", cs_grep)

  cs_lzgrep = cs_grep.clone
  cs_lzgrep.ret_proc = proc{|call| Enumerator::Lazy}
  CompSpec.def_method(Enumerator::Lazy, "grep", cs_lzgrep)

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

  cs_df = CompSpec.new
  cs_df.arg_proc do |call|
    CompArgProc(call) do |ap|
      ap.def_opt "--all", "-a", 
	desc: "include dummy file systems" ,
	ex: %w[-a --all]
      ap.def_opt "--block-size=", "-B+", 
	desc: "specify block size", message: "Block size",
	ex: %w[-B --block-size -k],
	act: %w[K M G T P E Z Y KB MB GB TB PB EB ZB YB]
      ap.def_opt "--exclude-type", "-x", 
	desc: "exclude file systems of specified type"
      ap.def_opt "--help", 
	desc: "display help and exit",
	ex: /.*/
      ap.def_opt "--human-readable", "-h", 
	desc: "print sizes in human readable format",
	ex: %w[-h --human-readable -H --si]
      ap.def_opt "--inodes", "-i", 
	desc: "list inode information instead of block usage",
	ex: %w[-i --inodes]
      ap.def_opt "--local", "-l", 
	desc: "limit listing to local file systems",
	ex: %w[-l --local]
      ap.def_opt "--no-sync", 
	desc: "do not invoke sync before getting usage info (default)",
	ex: %w[--sync]
      ap.def_opt "--portability", "-P", 
	desc: "use the POSIX output format",
	ex: %w[-P --portability]
      ap.def_opt "--print-type", "-T", 
	desc: "print file system type",
	ex: %w[-T --print-typee]
      ap.def_opt "--si", "-H", 
	desc: "human readable fomat, but use powers of 1000 not 1024",
	ex:  %w[-h --human-readable -H --si]
      ap.def_opt "--sync", 
	desc: "invoke sync before getting usage info",
	ex: %w[--no-sync]
      ap.def_opt "--total", 
	desc: "produce a grand total"
      ap.def_opt "--type=", "-t+", 
	desc: "limit listing to file systems of specified type", 
	message: "file system type",
	act: :file_systems
      ap.def_opt "--version", 
	desc: "output version information and exit",
	ex: /.*/
      ap.def_opt "-k", 
	desc: "like --block-size=1K",
	ex: %w[-B --block-size -k]
      ap.def_opt "-v", 
	desc: "(ignored)"
      ap.def_opt "-reishtest",
	desc: "test for reish"
      ap.def_opt "-r",
	desc: "test for reish"
      ap.def_arg :files
    end
  end
  CompSpec.def_command "df", cs_df

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

