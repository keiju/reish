#
#   comp-module-spec.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)

require "set"
require "reish/class-schema"

module Reish

  @ModuleSpecs = {}
  @DescendantSpecs = {}

  def self.ModuleSpec(mod)
    spec = @ModuleSpecs[mod]
    return spec if spec
    spec = ModuleSpec.new(mod)
    @ModuleSpecs[mod] = spec
    spec
  end

  def self.DescendantSpec(mod)
    spec = @DescendantSpecs[mod]
    return spec if spec
    spec = DescendantSpec.new(mod)
    @DescendantSpecs[mod] = spec
    spec
  end

  class ModuleSpec

    def initialize(mod)
      @mod = mod
    end

    attr_reader :mod
    alias module mod

    def superset?(other)
      case other
      when ModuleSpec
	@mod == other.mod
      when CompositeSpec, DescendantSpec
	!other.proper_subset?(self)
      else
	raise TypeError, "no supported type(#{other})"
      end
    end

    def proper_superset?(other)
      case other
      when ModuleSpec
	false
      when CompositeSpec, DescendantSpec
	!other.subset?(self)
      else
	raise TypeError, "no supported type(#{other})"
      end
    end

    def subset?(other)
      case other
      when ModuleSpec
	@mod == other.mod
      when CompositeSpec, DescendantSpec
	!other.proper_superset?(self)
      else
	raise TypeError, "no supported type(#{other})"
      end
    end

    def proper_subset?(other)
      case other
      when ModuleSpec
	false
      when CompositeSpec, DescendantSpec
	!other.superset?(self)
      else
	raise TypeError, "no supported type(#{other})"
      end
    end

    def |(other)
      case other
      when ModuleSpec
	if self == other
	  self
	else
	  CompositeSpec.new(self, other)
	end
      when CompositeSpec, DescendantSpec
	other | self
      else
	raise TypeError, "no supported type(#{other})"
      end
    end

    def instance_methods
      @mod.instance_methods
    end
  end

  class DescendantSpec

    def initialize(mod)
      @mod = mod
    end

    attr_reader :mod
    alias module mod

    def superset?(other)
      case other
      when ModuleSpec
	@mod >= other.mod
      when DescendantSpec
	@mod >= other.mod
      when CompositeSpec
	!other.proper_subset?(self)
      else
	raise TypeError, "no supported type(#{other})"
      end
    end

    def proper_superset?(other)
      case other
      when ModuleSpec
	@mod > other.mod
      when DescendantSpec
	@mod > other.mod
      when CompositeSpec
	!other.subset?(self)
      else
	raise TypeError, "no supported type(#{other})"
      end
    end

    def subset?(other)
      case other
      when ModuleSpec
	false
      when DescendantSpec
	@mod <= other.mod
      when CompositeSpec
	!other.proper_superset?(self)
      else
	raise TypeError, "no supported type(#{other})"
      end
    end

    def proper_subset?(other)
      case other
      when ModuleSpec
	false
      when DescendantSpec
	@mod < other.mod
      when CompositeSpec
	!other.superset?(self)
      else
	raise TypeError, "no supported type(#{other})"
      end
    end

    def |(other)
      case other
      when ModuleSpec
	if superset?(other)
	  self 
	else
	  CompisiteSpec.new(self, other)
	end
      when DescendantSpec
	if superset?(other)
	  self
	elsif subset?(other)
	  other
	else
	  CompisiteSpec.new(self, other)
	end
      when CompositeSpec
	other | self
      else
	raise TypeError, "no supported type(#{other})"
      end
    end

    def instance_methods
      SCHEMA[@mod].possivle_instance_methods
    end
  end

  class CompositeSpec
    #spec1とspec2はお互いに素
    def initialize(spec1, spec2)
      @specs = Set.new(spec1, spec2)
    end

    attr_reader :specs

    def superset?(other)
      case other
      when ModuleSpec, DescendantSpec
	@specs.any?{|spec| spec.superset?(other)}
      when CompositeSpec
	@specs.any?{|spec| !other.proper_subset?(spec)}
      else
	raise TypeError, "no supported type(#{other})"
      end
    end

    def proper_superset?(other)
      case other
      when ModuleSpec, DescendantSpec
	@specs.any?{|spec| spec.proper_superset?(other)}
      when CompositeSpec
	@specs.any?{|spec| !other.subset?(spec)}
      else
	raise TypeError, "no supported type(#{other})"
      end
    end

    def subset?(other)
      case other
      when ModuleSpec, DecendantSpec
	@specs.any?{|spec| spec.subset?(other)}
      when CompositeSpec
	@specs.any?{|spec| !other.proper_superset?(self)}
      else
	raise TypeError, "no supported type(#{other})"
      end
    end

    def proper_subset?(other)
      case other
      when ModuleSpec, DecendantSpec
	@specs.any?{|spec| spec.proper_subset?(other)}
      when CompositeSpec
	@specs.any?{|spec| !other.superset?(self)}
      else
	raise TypeError, "no supported type(#{other})"
      end
    end
      
    def |(other)
      case other
      when ModuleSpec
	if superset?(other)
	  self 
	else
	  CompositeSpec.new(self, other)
	end
      when DescendantSpec
	if superset?(other)
	  self
	elsif subset?(other)
	  other
	else

	  specs_n = nil
	  @specs.each do |spec|
	    if spec.superset?(other)
	      specs_n = Set.new(@specs) unless specs_n
	      specs_n.delete(spec)
	      specs_n << other
	    end
	  end
	  if specs_n
	    CompositeSpec.new(*specs_n)
	  else
	    self
	  end
	end
      when CompositeSpec
	if superset?(other)
	  self
	elsif subset?(other)
	  other
	else
	  comp = self
	  other.specs.each do |spec|
	    comp |= spec
	  end
	  comp
	end
      else
	raise TypeError, "no supported type(#{other})"
      end
    end

    def instance_methods
      methods = Set.new
      @specs.each do |spec|
	mehotds.merge spec.instance_methods
      end
      methods
    end
    
  end
end

