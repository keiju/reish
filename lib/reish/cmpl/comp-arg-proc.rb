# coding: utf-8
#
#   comp-exec.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "set"

require "reish/cmpl/comp-action"
require "reidline/mcol-messenger"

module Reish
  class CompArgProc
    include CompAction

    class OptFamily
      def initialize(opt1, opt2=nil, desc: nil,  exclude: nil, message: nil, act: nil)
	@opts = []
	[opt1, opt2].each do |opt|
	  if opt
	    opt_spec = OptSpec.new(self, opt)
	    @opts.push opt_spec
	    #	  @opt2spec[sopt_spec.opt] = opt_spec
	  end
	end
	@description = desc
	@exclude = exclude
	@message = message
	@action = act
      end

      attr_reader :opts
      attr_reader :description
      attr_reader :exclude
      attr_reader :message
      attr_reader :action
    end

    class OptSpec
      def initialize(family, opt)
	@family = family
	@arg = nil

	@arg_optional = nil
	case opt
	when /^(.*)-(\?)?$/
	  @opt = $1
	  @arg = :CLOSE
	  @arg_optional = $2 if $2
	when /^(.*)\+(\?)?$/
	  @opt = $1
	  @arg = :SPACE
	  @arg_optional = $2 if $2
	when /^(.*)==(\?)?$/
	  @opt = $1
	  @arg = :EQUAL_ONLY
	  @arg_optional = $2 if $2
	when /^(.*)=(\?)?$/
	  @opt = $1
	  @arg = :EQUAL
	  @arg_optional = $2 if $2
	else
	  @opt = opt
	end
      end

      attr_reader :family
      attr_reader :opt

      def long?
	/^--/ =~ @opt || /^-[\w][\w]+/ =~ @opt
      end

      def short?
	/^-\w$/ =~ @opt
      end

      def with_arg?
	@arg
      end

      def arg_close_only?
	@arg == :CLOSE
      end

      def arg_space?
	@arg == :SPACE
      end

      def arg_equal?
	@arg == :EQUAL
      end

      def arg_equal_only?
	@arg == :EQUAL_ONLY
      end

      def arg_optional?
	@arg_optional
      end

      def arg_separator
	case @arg
	when :CLOSE
	  ""
	when :SPACE
	  " "
	when :EQUAL
	  " "
	when :EQUAL_ONLY
	  "="
	end
      end

      def exclude
	@family.exclude
      end

      def action
	@family.action
      end

      def inspect
	"#{self.to_s.chop}: @opt=#{@opt.inspect}, @arg=#{@arg.inspect}, @arg_optional=#{@arg_optional.inspect}, @family=#{@family}, action=#{action.inspect}, exclude=#{exclude.inspect}"
      end

    end

    class OptSet
      def initialize
	@set = Set.new
	@patterns = []
      end

      def << other
	case other
	when Enumerable
	  other.each do |e|
	    self << e
	  end
	when Symbol
	  @set << other.id2name
	when String
	  @set << other
	when Regexp
	  @patterns.push other
	else
	  raise "想定していないものです(#{other.inspect})"
	end
      end

      def include?(other)
	@set.include?(other) || 
	  @patterns.find{|p| p === other}
      end
    end

    def initialize(call)
      @title = nil

      @call = call
      @opts = []
      @candidates = []
      @excludes_opt = OptSet.new
    end

    def empty?
      @candidates.empty?
    end
    
    def size
      @candidates.size
    end

    def opt_spec(key)
      each_opt do |spec|
	return spec if spec.opt == key
      end
      nil
    end

    # -opt, --opt
    #       -opt-, -opt+, --opt=, --opt==
    #       -opt-?, -opt+?, --opt=?, --opt==?
    # --opt
    def def_opt(opt1, opt2=nil, desc: nil, ex: nil, exclude: ex, message: nil, act: nil)
      family = OptFamily.new(opt1, opt2, desc: desc, exclude: exclude, message: message, act: act)

      @opts.push family
    end

    def each_opt(&block)
      if block_given?
	@opts.each do |family|
	  family.opts.each do |opt_spec|
	    block.call opt_spec
	  end
	end
      else
	Enumerator.new(self, :each_opt)
      end
    end

    def each_short_opt(&block)
      if block_given?
	each_opt do |opt_spec|
	  block.call opt_spec if opt_spec.short? 
	end
      else
	Enumerator.new(self, :each_short_opt)
      end
    end

    def def_arg(act)
      case act
      when Symbol
	@arg_action =  method(act)
      else
	@arg_action = act
      end
    end

    def files(arg = nil)
      ca_files(@call, arg)
    end

    def candidates
      arg_opt_p = nil
      @call.args.each do |arg|
	if arg == @call.last_arg
	  if arg_opt_p
	    return candidates_last_arg(arg_opt_p, arg)
	  else
	    return candidates_last_arg(arg)
	  end
	end

	next if arg_opt_p
	arg_opt_p = nil


	case arg
	when WordToken
	  case arg.value
	  when /^(-.*)=(.*)$/
	    if ex = opt_spec(arg.value)&.exclude
	      @excludes_opt << ex
	    end
	  when /^--/
	    if spec = opt_spec(arg.value)
	      arg_opt_p = arg if spec.with_arg?
	      if ex = spec.exclude
		@excludes_opt << ex
	      end
	    end
	  when /^-(.*)$/
	    if spec = opt_spec(arg.value)
	      arg_opt_p = arg if spec.with_arg?
	      if ex = spec.exclude
		@excludes_opt << ex
	      end
	    else
	      sopts = $1.chars
	      while k = sopts.shift
		if spec2 = opt_spec("-"+k)
		  if ex = spec2.exclude
		    @excludes_opt << ex
		  end
		  if spec2.with_arg?
		    if sopts.empty?
		      arg_opt_p = arg
		    end
		    break
		  end
		end
	      end
	    end
	  else
	    # 引数の最後ではないのに通常引数が来た場合
	    return @arg_action.call
	  end
	when StringToken #, CompositeWord
	  raise "not implemented"
	else
	  raise "not implemented token=(#{arg.inspect})"
	end
	next
      end

      if arg_opt_p
	return candidates_last_arg_with_space(@call.args.elements.last)
      end

      return @arg_action.call
    end

    def candidates_last_arg(arg, last_arg = nil)
      case arg
      when WordToken
	case arg.value
	when /^(-.*)=(.*)$/
	  # ここで, message出力
	  if (spec = opt_spec($1))&.with_arg?
	    return act_option_arg(spec, $1, $2, "=")
	  else
	    return []
	  end

	when /^--/
	  spec = opt_spec(arg.value)
	  if spec
	    # オプション引数確定
	    if spec.with_arg?
	      return act_option_arg(spec, arg.value, option_arg: last_arg&.value)
	    else
	      return arg.value
	    end
	  else
	    return candidates_long_opt(arg.value)
	  end

	when /^-/
	  spec = opt_spec(arg.value)
	  if spec
	    # オプション確定
	    if ex = spec.exclude
	      @excludes_opt << ex
	    end
	    if spec.with_arg?
	      # オプション引数確定
	      return act_option_arg(spec, arg.value, option_arg: last_arg&.value)
	    else
	      return candidates_short_opt(arg.value)
	    end
	  else
	    cand = candidates_long_opt(arg.value)
	    return cand if !cand.empty?
	    
	    key = ""
	    sopts = arg.value.chars
	    key.concat sopts.shift
	    while k = sopts.shift
	      key.concat k
	      spec2 = opt_spec("-"+k)
	      if spec2
		if spec2.with_arg?
		  if sopts.empty?
		    return act_option_arg(spec2, key, "", option_arg: last_arg&.value)
		  else
		    return act_option_arg(spec2, key, "", option_arg: sopts.join, option_arg_closed: true)
		  end
		else
		  if ex = spec2.exclude
		    @excludes_opt << ex
		  end
		end
	      else
		return []
	      end
	    end
	    return candidates_short_opt(arg.value)
	  end
	else
	  # 通常引数(途中まで入力)の場合
	  return @arg_action.call(arg.value)
	end
      when StringToken, CompositeWord
	raise "not implemented"
      else
	raise "not implemented"
      end
    end

    def candidates_last_arg_with_space(arg)
      case arg
      when WordToken
	case arg.value
	when /^(-.*)=(.*)$/
	  # pass throw
	when /^--/
	  if(spec = opt_spec(arg.value))&.with_arg?
	    return act_option_arg(spec, arg.value)
	  end
	  
	when /^-/
	  if (spec = opt_spec(arg.value))&.with_arg?
	    # オプション引数確定
	    return act_option_arg(spec, arg.value)
	  else
	    key = ""
	    sopts = arg.value.chars
	    key.concat sopts.shift
	    while k = sopts.shift
	      key.concat k
	      spec2 = opt_spec("-"+k)
	      if spec2
		if spec2.with_arg?
		  if sopts.empty?
		    return act_option_arg(spec2, key)
		  end
		end
	      end
	    end
	  end
	else
	end
      when StringToken, CompositeWord
	raise "not implemented"
      else
	raise "not implemented"
      end
    end

    def candidates_long_opt(arg)
      @candidates = []
      each_opt do |opt_spec|
	next if @excludes_opt.include?(opt_spec.opt)

	opt = opt_spec.opt
	if opt[0..arg.size-1] == arg || opt == arg[0..opt.size]
	  @candidates.push opt_spec 
	end
      end

      case @candidates.size
      when 0
	return []
      when 1
	return [@candidates.first.opt]
      else
	# path throw
      end

      t_size = arg.size
      c_set = @candidates.sort_by{|cand| cand.opt}
      match = c_set.last.opt.chars
      c_set.each do |opt_spec|
	n_match = []
	match.each_with_index do |m, i|
	  break unless m == opt_spec.opt[i]
	  n_match.push m
	end
	match = n_match
	if match.size == t_size
	  break
	end
      end
      
      if match.size == t_size
	self
      else
	match.join
      end
    end

    def candidates_short_opt(arg)
      @candidates = []
      each_short_opt do |opt_spec|
	next if @excludes_opt.include?(opt_spec.opt)

	@candidates.push opt_spec
      end

      case @candidates.size
      when 0
	[]
      when 1
	[@candidates.first.opt]
      else
	self
      end
    end

    def act_option_arg(spec, opt, sep = spec.arg_separator, option_arg: nil, option_arg_closed: false)
      @title = spec.family.message
      case spec.action
      when nil
	[]
      when Array
	@candidates = spec.action
	@candidates = ca_filter(@candidates, nil, option_arg)
      when Symbol
	@candidates = self.send spec.action
	@candidates = ca_filter(@candidates, nil, option_arg)
      when Proc
	spec.action.call(self, opt, option_arg)
      end

      case @candidates.size
      when 0
	[]
      when 1
	if option_arg
	  if option_arg_closed
	    [opt+sep+@candidates.first]
	  else
	    [@candidates.first]
	  end
	else
	  [opt+sep+@candidates.first]
	end
      else
	self
      end
    end

    def message_to(editor)
      case @candidates.first
      when OptSpec
	pager = Reidline::MColMessenger.new
	pager.set_title "Completing #{@title}:" if @title
	@candidates.collect{|opt_spec| opt_spec.family}.uniq.each do |family|
	  opts = family.opts.collect{|spec| spec.opt}
	  pager.push [opts[0], opts[1], family.description]
	end
	editor.message pager: pager
      when String
	pager = Reidline::LamMessenger.new(@candidates)
	pager.set_title "Completing #{@title}:" if @title
	editor.message pager: pager
      end
    end

    def for_readline
      cands = []
      @candidates.each do |e|
	case e
	when OptSpec
	  cands.push e.opt if e.long?
	when String
	  cands.push e if /^--/ =~ e || /^-[\w][\w]+/ =~ e
	end
      end
      cands.sort.uniq
    end

  end

  def self.CompArgProc(call, &block)
    ce = CompArgProc.new(call)
    block.call(ce)
    ce.candidates
  end
end

