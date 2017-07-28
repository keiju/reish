#
#   reish/system-command.rb - 
#   	Copyright (C) 2014-2017 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

module Reish
  def Reish.SystemCommand(exenv, receiver, path, *args)
    case receiver
    when Reish::Main
      c = SystemCommand.new(exenv, receiver, path, *args)
    when SystemCommand
      c = CompSystemCommand.new(exenv, receiver, path, *args)
    when Lazize
      c = CompSystemCommand.new(exenv, receiver.source, path, *args)
    else
      c = SystemCommand.new(exenv, receiver, path, *args)
    end
    Lazize.lazize(c)
  end

  module Lazize
    def self.lazize(c)
      l = c.lazy
      l.extend self
      l.instance_eval{@source = c}
      l
    end

    attr_reader :source
    
    def reish_term
      @source.reish_term
    end
    alias term reish_term

    def reish_result
      @source.reish_result
    end
    alias result reish_result

    def info
      "Lazy(#{@source.info})"
    end
  end
    
  class SystemCommand
    include Enumerable
    include OSSpace

    def initialize(exenv, receiver, path, *args)
      @exenv = exenv
      @receiver = receiver
      @command_path = path
      @args = args

      @reds = nil

      @pid = nil
      @pstat = :NULL
      @exit_status = nil

      @wait_mx = Mutex.new
      @wait_cv = ConditionVariable.new
    end

    attr_reader :exenv
    attr_reader :receiver
    attr_reader :command_path
    attr_accessor :reds

    def exection_class
      CommandExecution
    end


    def command_opts(ary = @args)
      opts = []
      ary.each do |e|
	case e
	when true, false, nil, Numeric, Class
	  opts.push e.to_s
	when String
	  opts.push e
	when Array
	  opts.concat command_opts(e)
	when Hash
	  opts.concat e.collect{|key, value| "--#{key}=#{value}"}
	when Symbol
	  opts.push "--"+e.id2name
	else
	  e.reish_append_command_opts(opts)
	end
      end
      opts
    end

    def each(&block)
      if receive?
	mode = "r+"
      else
	mode = "r"
      end

      exec = exection_class.new(self)
      exec.popen(mod) do |io|
	if receive?
	  case receiver
	  when Enumerable
	    Thread.start do
	      begin
		@receiver.each {|e| io.print e.to_s}
	      rescue
		p $!
		raise
	      ensure
		io.close_write
	      end
	    end
	  else
	    io.write @receiver.to_s
	    io.close_write
	  end
	end
	io.each &block
      end
    end

    def term
      exec = exection_class.new(self)
      if receive?
	exec.popen("w") do |io|
	  case receiver 
	  when Enumerable
	    @receiver.each{|e| io.puts e.to_s}
	  else
	    io.write @receiver.to_s
	  end
	  io.close
	  @exit_status = $?
	end
      else
	exec.spawn
      end

      @exit_status
    end

    def reish_result
      self.to_a
    end

    alias reish_term term

    def receive?
      !@receiver.kind_of?(Reish::Main)      
    end

    def each_open_mode
      if receiver.kind_of?(Reish::Main)
	"r"
      else
	"r+"
      end
    end

    def read_from_receiver(io)
      begin
	case receiver
	when Enumerable
	  Thread.start do
	    @receiver.each {|e| io.puts s.to_s}
	  end
	when Reish::Main
	  # do nothing
	else
	  io.write @receiver.to_s
	end
      ensure
	  io.close_write
      end
    end

    def to_script
      @command_path +" "+ @args.collect{|e| e.to_s}.join(" ")
    end

    def exit_status
      unless @exit_status
	term
      end
      @exit_status
    end

    def spawn_options
      opts = {:chdir => @exenv.pwd}
      return opts unless @reds

      @reds.each do |red|
	key, value = red.spawn_option_key_value
	opts[key] = value
      end

      opts
    end

    def info
      "#{File.basename(@command_path)}[#{@pid}](#{@pstat.id2name})"
    end

    def inspect
      if Reish::INSPECT_LEBEL < 3
	format("#<SystemCommand: @receiver=%s, @command_path=%s, @args=%s, @exis_status=%s>", @receiver, @command_path, @args, @exit_status)
      else
	super
      end
    end
  end

  class CompSystemCommand<SystemCommand
    def initialize(exenv, receiver, path, *args)
      super
      
      @receiver = receiver.receiver
      @receiver_script = receiver.to_script
      if receiver.reds
	@receiver_script.concat receiver.reds.collect{|r| r.command_option_str}.join(" ")
      end
    end

    def exection_class
      ShellExecution
    end

    def to_script
      @receiver_script + "|" +
	@command_path + " " + command_opts.join(" ")
    end

    def info
      "#{to_script}[#{pid}](#{@pstat.id2name})"
    end
  end

  class ConcatCommand
    include Enumerable

    def initialize(*commands)
      @commands = commands
    end

    def each(&block)
      @commands.each{|com| com.each &block}
    end

    def reish_result
      self.to_a
    end
  end

  def Reish::WildCard(wc)
    exenv = Reish::current_shell.exenv
    WildCard::new(exenv, wc)
  end

  class WildCard
    include Enumerable

    def initialize(exenv, pat)
      @exenv = exenv
      @pattern = pat
    end

    attr_reader :pattern

    def +(other)
      case other
      when String
	WildCard.new(@exenv, @pattern + other)
      when WildCard
	WildCard.new(@exenv, @pattern + other.pattern)
      else
	raise ArgumentError, "don't support this object's type(#{other})"
      end
    end

    def right_assoc_plus(other)
      case other
      when String
	WildCard.new(@exenv, other+@pattern)
      else
	raise ArgumentError, "don't support this object's type(#{other})"
      end
    end

    def ===(other)
      File.fnmatch?(@pattern, other)
    end

    def glob
      if @pattern[0] == "/"
        files = Dir[@pattern]
      else
        prefix = @exenv.pwd+"/"
        files = Dir[prefix+@pattern].collect{|p| p.sub(prefix, "")}
      end
    end

    def each(&block)
      self.glob.each &block
    end

    def append_command_opts(opts)

      files = glob

      if files.empty?
	opts.push @pattern
      else
	opts.concat files
      end
    end

    alias reish_append_command_opts append_command_opts

    def inspect
      if Reish::INSPECT_LEBEL < 3
	"#<WildCard: #{@pattern}>"
      else
	super
      end
    end
  end

  def Reish::Redirect(*opts)
    Redirect::new(*opts)
  end

  class RedirectionCommand

    def initialize(method, args, reds, &block)
      @method = method
      @args = args
      @reds = reds
      @block = block
    end
  end

  class Redirect
    def initialize(src, id, red, over = nil)
      @source = src
      @id = id
      @red = red
      @over = over
    end

    attr_reader :source
    attr_reader :id
    attr_reader :red
    attr_reader :over

    def command_option_str
      "#{@source}#{id}#{red}"
    end

    def spawn_option_key_value
      case @id
      when ">", "&>"
	[source_fid, [@red, "w"]]
      when ">>", "&>>"
	[source_fid, [@red, "a"]]
      when "<"
	[source_fid, @red]
      end
    end

    def source_fid
      case id
      when "<"
	0
      when ">", ">>"
	1
      when "&>", "&>>"
	[1, 2]
      end
    end

    def open_mode
      case @id
      when ">", "&>"
	"w"
      when ">>", "&>>"
	"a"
      when "<"
	"r"
      end
    end
  end

end


class Object
  def reish_term
    case self
    when Array
#      puts collect{|e| e.to_s}.sort
	each{|e| puts e.to_s}
    when Enumerable
      if STDOUT.tty?
	each{|e| puts e.to_s}
      else
	each{|e| puts e.to_s}
      end
    else
      puts self.to_s
    end
    self
  end


  def reish_stat; self; end
  def reish_result; self; end

  def reish_append_command_opts(opts)
    begin
      st = self.to_str
      opts.push st
    rescue
      super
    end
  end

  def reish_send_with_redirection(method, args, reds, &block)
    Reish::Fail NotExistCurrentShell unless Reish::active_thread?
    Reish::current_shell.send_with_redirection(self, method, args, reds, &block)
  end

  def reish_shell_command_with_redirection(code, reds, bind)
    Reish::Fail NotExistCurrentShell unless Reish::active_thread?
    Reish::current_shell.shell_command_with_redirection(self, code, reds, bind)
  end

  def reish_attach_redirection(*reds)

    input = nil
    output = nil

    reds.each do |red|
      case red.id
      when ">"
	if red.source != 1
	  raise ArgumentError, "biltin ruby method not support redirection except etdout"
	end
	case red.red
	when Integer
	  output = IO.open(red.red, "w")
	when String
	  output = File.open(red.red, "w")
	end
      when ">>"
	if red.source != 1
	  raise ArgumentError, "biltin ruby method not support redirection except etdout"
	end
	case red.red
	when Integer
	  output = IO.open(red.red, "a")
	when String
	  output = File.open(red.red, "a")
	end
      when "<"
	if red.source != 0
	  raise ArgumentError, "biltin ruby method not support redirection except etdin"
	end
	case red.red
	when Integer
	  input = IO.open(red.red, "r")
	when String
	  input = File.open(red.red, "r")
	end
      end
    end

    if input
      input.each do |e|
	
      end
    end
  end

  def reish_eval(code, bind)
    Thread.current[:__REISH_SELF__] = self
    eval(%{Thread.current[:__REISH_SELF__].instance_eval %{#{code}}}, bind)
  end
end

class String
  alias plus_org +
  
  def +(other)
    if other.class == Reish::WildCard
      other.right_assoc_plus(self)
    else
      self.plus_org(other)
    end
  end
end

class Regexp
  def reish_append_command_opts(opts)
    opts.push self.source
  end
end


    
  
