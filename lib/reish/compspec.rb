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
      unless  /^\// =~ name
	for cls in receiver.class.ancestors
	  spec = M2Spec[[cls, name]]
	  if spec
	    puts "Match CompSpec for #{cls}##{name} spec: #{spec.inspect}"
	    return spec
	  end
	end
	return DefaultRubyMethodCS if receiver.respond_to?(name)
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
    
    def arg_candidates(call)
      return @arg_proc.call call if @arg_proc
      []
    end

    def return_value(call)
      return @ret_proc.call call if @ret_proc
      Object
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

    def options(call, filter=nil, sopt = "", lopts = [])
      opts = sopt.split(//).collect{|c| "-" + c}
      opts.concat lopts

      filter(opts, call, filter)
    end

    def commands(call, filter=nil)
      exenv = eval("@exenv", call.bind)
      shell = exenv.shell
      filter shell.all_commands, call, filter
    end

    def commands_arg_proc
      proc{|call| commands(call)}
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
  
  class CompCommandArg
    def initialize(receiver, name, args, last_arg, bind)
      @receiver = receiver
      @name = name
      @args = args
      @last_arg = last_arg
      @bind = bind
    end

    attr_reader :bind
    attr_reader :receiver
    attr_reader :compspec
    attr_reader :args
    attr_reader :last_arg

    def candidates
      case @name
      when IDToken
	n = @name.value
      when SpecialToken
	n = "Special#"+@name.value

      when ReservedWordToken
	n = "RESERVED#"+@name.token_id.to_s

      when TestToken
	n = "TEST#"+@name.token_id.to_s

      else
	raise "not implemented for token: #{@name.inspect}"
      end
      spec = Reish::CompSpec(@receiver, n)
      spec.arg_candidates(self)
    end
  end

  class CompCommandCall
  end

  DefaultRubyMethodCS = CompSpec.new
  DefaultRubyMethodCS.arg_proc = DefaultRubyMethodCS.objects_arg_proc
  DefaultRubyMethodCS.ret_proc = proc{|call| Object}

  DefaultSystemCommandCS = CompSpec.new
  DefaultSystemCommandCS.arg_proc = DefaultSystemCommandCS.files_arg_proc
  DefaultSystemCommandCS.ret_proc = proc{|call| SystemCommand}

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
  command_arg_cs.arg_proc = command_arg_cs.commands_arg_proc
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

  CompSpec.def_command "ls", cs_ls

end

