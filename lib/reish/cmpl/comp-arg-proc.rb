#
#   comp-exec.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "reish/cmpl/comp-action"
require "reish/reidline/mcol-pager"

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
      attr_reader :acion
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
	/^--/ =~ @opt
      end

      def short?
	!long?
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

      def inspect
	"#{self.to_s.chop}: @family=#{@family} @opt=#{@opt.inspect}, @arg=#{@arg.inspect}, @arg_optional=#{@arg_optional.inspect}>"
      end

    end

    def initialize(call)
      @call = call
      @opts = []
      @candidates = []
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
    def def_opt(opt1, opt2=nil, desc: nil, exclude: nil, message: nil, act: nil)
      family = OptFamily.new(opt1, opt2, desc: desc, exclude: exclude, message: message, act: act)

      @opts.push family
    end

    def each_opt(&block)
      @opts.each do |family|
	family.opts.each do |opt_spec|
	  block.call opt_spec
	end
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

    def files
      ca_files(@call)
    end

    def candidates
      arg_opt_p = nil
      @call.args.each do |arg|
	next if arg_opt_p
	arg_opt_p = false

	if arg != @call.last_arg
	  case arg
	  when WordToken
	    case arg.value
	    when /^(--.*)=(.*)$/
	      # do nothing
	    when /^--/
	      arg_opt_p = true if opt_spec(arg.value)&.with_arg?
	    when /^-(.*)$/
	      if opt_spec(arg.value)&.with_arg?
		arg_opt_p = true
	      else
		sopts = $1.chars
		while k = sopts.shift
		  if opt_spec("-"+k)&.with_arg?
		    if sopts.empty?
		      arg_opt_p = true
		    end
		    break
		  end
		end
	      end
	    else
	      # 引数の最後ではないのに通常引数が来た場合
	      raise "not implemented"
	    end
	  when StringToken, CompositeWord
	    raise "not implemented"
	  else
	    raise "not implemented"
	  end
	  next
	end

	case arg
	when WordToken
	  case arg.value
	  when /^(--.*)=(.*)$/
	    # ここで, message出力
	    if (spec = opt_spec($1)) && spec.action
	      # ここで, action実行
	      return "--candidates--"
	    else
	      return []
	    end

	  when /^--/
	    spec = opt_spec(arg.value)
	    if spec
	      # オプション引数確定
	      if spec.with_arg?
		# ここで, message出力
		if spec.action
		  # ここで, action実行
		  return "--candidates--"
		else
		  return []
		end
	      else
		return arg.value
	      end
	    else
	      return candidates_long_opt(arg.value)
	    end

	  when /^-/
	    spec = opt_spec(arg.value)
	    if spec && spec.with_arg?
	      # オプション引数確定
	      if spec.action
		# ここで, action実行
		return "--candidates--"
	      else
		return []
	      end
	    else
	      sopts = arg.value.chars
	      while k = sopts.shift
		spec2 = opt_spec("-"+k)
		if spec2.with_arg?
		  if sopts.empty?
		    # ここで, メッセージ出力
		    # action実行
		  else
		    # ここで, メッセージ出力
		    # action実行(with sopts)
		  end
		end
	      end
	      # ロング&ショートオプションの絞り込み候補表示
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

      return @arg_action.call
    end

    def candidates_long_opt(arg)
      @candidates = []
      each_opt do |opt_spec|
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

    def display(editor)
      pager = Reidline::MColPager.new(editor.view)
      @candidates.collect{|opt_spec| opt_spec.family}.uniq.each do |family|
	opts = family.opts.collect{|spec| spec.opt}
	pager.push [opts[0], opts[1], family.description]
      end
      editor.message pager: pager
    end

  end

  def self.CompArgProc(call, &block)
    ce = CompArgProc.new(call)
    block.call(ce)
    ce.candidates
  end
end

