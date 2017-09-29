#
#   class-schema.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)

require "set"

module Reish

  class Schema
    def initialize
      @schema = {}
    end

    def [](mod)
      make_schema if @schema.empty?

      unless sc = @schema[mod]
	sc = SchemaElement.new(mod)
	@schema[mod] = sc
      end
      sc
    end

    def remake
      @schema.clear
      make_schema
    end

    def make_schema
      @schema[Object] = SchemaElement.new(Object)

      ObjectSpace.each_object(Module) do |mod|
	mod.included_modules.each do |m|
	  self[m].add_included(mod)
	end
	begin
	  self[mod.superclass].add_subclass mod
	rescue
	  #p $!
	end
      end
    end
  end

  SCHEMA = Schema.new

  class SchemaElement
    def initialize(mod)
      @mod = mod

      @included = []
      @subclasses = []
    end

    attr_reader :included
    attr_reader :subclasses

    def class?
      @mod.kind_of?(Class)
    end

    def include_modules
      mod.included_modules
    end

    def ancesters
      @mod.ancesters
    end

    def superclass
      @mod.kind_of?(Class) && @mod.superclass
    end

    def all_subclasses(set = Set.new)
      @subclasses.each do |s|
	unless set.member?(s)
	  set << s
	  SCHEMA[s].all_subclasses(set)
	end
      end
      set
    end

    def possivle_instance_methods
      methods = Set.new @mod.instance_methods

      all_subclasses.each do |cls|
	next if cls == @mod
	methods.merge cls.instance_methods(false)
      end
      methods.sort
    end

    def add_included(mod)
      @included.push mod
    end

    def add_subclass(cls)
      @subclasses.push cls
    end

  end

end

