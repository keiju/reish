#!/usr/local/bin/ruby
#
#   reish/system-command.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

module Reish
  def Reish.SystemCommand(shell, receiver, path, *args)
    case receiver
    when Reish::Main
      SystemCommand.new(shell, receiver, path, *args)
    when SystemCommand
      CompSystemCommand.new(shell, receiver, path, *args)
    else
      SystemCommand.new(shell, receiver, path, *args)
    end
  end
    
  class SystemCommand
    include Enumerable
    include OSSpace

    def initialize(shell, receiver, path, *args)
      @__shell__ = shell
      @receiver = receiver
      @command_path = path
      @args = args

      @exit_status = nil
    end

    attr_reader :receiver

    def io_popen(mode, &block)
      IO.popen([@__shell__.system_env, 
		 @command_path, 
		 *command_opts], mode, &block)
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
	else
	  e.reish_append_command_opts(opts)
	end
      end
      opts
    end

    def io_spawn
      pid = Process.spawn(@__shell__.system_env, 
			  @command_path, 
			  *command_opts)
      pid
    end

    def each(&block)
      if receive?
	mode = "r+"
      else
	mode = "r"
      end

      io_popen(mode) do |io|
	if receive?
	  case receiver
	  when Enumerable
	    Thread.start do
	      begin
		@receiver.each {|e| io.puts s.to_s}
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
      if receive?
	io_popen("w") do |io|
	  case receiver 
	  when Enumerable
	    @receiver.each{|e| io.print e.to_s}
	  else
	    io.write @receiver.to_s
	  end
	  io.close
	  @exit_status = $?
	end
      else
	pid = io_spawn
	begin
	  pid2, stat = Process.waitpid2(pid)
	  @exit_status = stat
	rescue Errno::ECHILD
	  puts "#{command_path} not stated"
	end
      end

      @exit_status
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

    def inspect
      if Reish::INSPECT_LEBEL < 3
	format("#<SystemCommand: @receiverr=%s, @command_path=%s, @args=%s, @exis_status=%s>", @receiver, @command_path, @args, @exit_status)
      else
	super
      end
    end
  end

  class CompSystemCommand<SystemCommand
    def initialize(shell, receiver, path, *args)
      super
      
      @receiver = receiver.receiver
      @receiver_script = receiver.to_script
    end

    def io_popen(&block)
      IO.popen(@__shell__.system_env, to_script, open_mode, &block)
    end

    def io_spawn
      Process.spawn(@__shell__.system_env, to_script)
    end

    def to_script
      @receiver_script + "|" +
	@command_path + " " + command_opts.join(" ")
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

  end

  def Reish::WildCard(wc)
    sh = Thread.current[:__REISH_CURRENT_SHELL__]
    WildCard::new(sh, wc)
  end

  class WildCard
    def initialize(sh, pat)
      @shell = sh
      @pattern = pat
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

    def glob
      if @pattern[0] == "/"
        files = Dir[@pattern]
      else
        prefix = @shell.pwd+"/"
        files = Dir[prefix+@pattern].collect{|p| p.sub(prefix, "")}
      end
    end

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

  class Redirect
    def initialize(src, id, red, over = nil)
      @source = source
      @id = id
      @red = red
      @over = over
    end

    attr_reader :source
    attr_reader :id
    attr_reader :red
    attr_reader :over
  end

end


class Object
  def reish_term; self; end
  def reish_stat; self; end
  def reish_result; self; end
end

    
  
