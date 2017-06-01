module Reish

  def Reish::CompSpec(receiver, name)
    CompSpec.spec(receiver, name)
  end

  class CompSpec

    N2Spec = {}
    K2Spec = {}

    def CompSpec.def_command(name, spec)
      N2Spec[n] = spec
    end

    def CompSpec.def_method(klass, name, spec)
      K2Spec[klass, name] = spec
    end

    def CompSpec.spec(receiver, name)
      unless  /^\// =~ name
	spec = K2Spec[[receiver.class, name]]
	return spec if spec
	return RubyMethodCS if receiver.respond_to?(name)
      end

      spec = N2Spec[name]
      rerurn spec if spec
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

    def objects(call, filer: nil)
      []
    end

    def objects_arg_proc
      proc{|call| objects(call)}
    end

    def files(call, filter: nil)
      exenv = eval("@exenv", call.bind)
      if exenv
	pwd = exenv.pwd
      else
	pwd = Dir.pwd
      end

      arg = nil
      if filter
	if filter == true && 
	    arg = call.comp_arg
	else
	  arg = filter
	end
      end

      if arg
	l = pwd.size
	Dir["#{pwd}/#{arg}*" , File::FNM_DOTMATCH].collect{|e| e[1, l]= ""; e}
      else
	Dir.entries(pwd).select{|e| /^\./ !~ e}
      end
    end
    
    def files_arg_proc
      proc{|call| files(call)}
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
    attr_reader :comp_arg

    def candidates
      spec = Reish::CompSpec(@receiver, @name.value)
p spec
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

end

