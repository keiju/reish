#
#   rei/inspector.rb - inspect methods
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
# --
#
#   
#

module REI

  def REI::Inspector(inspect, init = nil)
    Inspector.new(inspect, init)
  end

  class Inspector
    def initialize(inspect_proc, init_proc = nil)
      @init = init_proc
      @inspect = inspect_proc
    end

    def init
      @init.call if @init
    end

    def inspect_value(v)
      @inspect.call(v)
    end
  end

  INSPECTORS = {}

  def INSPECTORS.keys_with_inspector(inspector)
    select{|k,v| v == inspector}.collect{|k, v| k}
  end

  # ex)
  # INSPECTORS.def_inspector(key, init_p=nil){|v| v.inspect}
  # INSPECTORS.def_inspector([key1,..], init_p=nil){|v| v.inspect}
  # INSPECTORS.def_inspector(key, inspector)
  # INSPECTORS.def_inspector([key1,...], inspector)

  def INSPECTORS.def_inspector(key, arg=nil, &block)
#     if !block_given?
#       case arg
#       when nil, Proc
# 	inspector = IRB::Inspector(init_p)
#       when Inspector
# 	inspector = init_p
#       else
# 	IRB.Raise IllegalParameter, init_p
#       end
#       init_p = nil
#     else
#       inspector = IRB::Inspector(block, init_p)
#     end
      
    if block_given?
      inspector = REI::Inspector(block, arg)
    else
      inspector = arg
    end
    
    case key
    when Array
      for k in key
	def_inspector(k, inspector)
      end
    when Symbol
      self[key] = inspector
      self[key.to_s] = inspector
    when String
      self[key] = inspector
      self[key.intern] = inspector
    else
      self[key] = inspector
    end
  end

  INSPECTORS.def_inspector([false, :to_s, :raw]){|v| v.to_s}
  INSPECTORS.def_inspector([true, :p, :inspect]){|v| v.inspect}
  INSPECTORS.def_inspector([:pp, :pretty_inspect], proc{require "pp"}){|v| v.pretty_inspect.chomp}
  INSPECTORS.def_inspector([:yaml, :YAML], proc{require "yaml"}){|v| 
    begin
      YAML.dump(v)
    rescue
      puts "(can't dump yaml. use inspect)"
      v.inspect
    end
  }

  INSPECTORS.def_inspector([:marshal, :Marshal, :MARSHAL, Marshal]){|v| 
    Marshal.dump(v)
  }
end


  
    

