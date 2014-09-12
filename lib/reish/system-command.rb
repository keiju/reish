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
    end

    attr_reader :receiver

    def each(&block)
      IO.popen([@__shell__.system_env, 
		 @command_path, 
		 @args.collect{|e| e.to_s}], open_mode) do |io|
	io.each &block
      end
    end

    def execute
      pid = Process.spawn(@__shell__.system_env, 
			  @command_path, 
			  *@args.collect{|e| e.to_s})
      begin
	pid2, stat = Process.waitpid2(pid)
	stat.exitstatus
      rescue Errno::ECHILD
	puts "#{command_path} not stated"
      end
    end

    alias stat execute 
    alias reish_stat stat

    def open_mode
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
      @command_path + @args.collect{|e| e.to_s}.join(" ")
    end
  end

  class CompSystemCommand<SystemCommand
    def intialize(shell, receiver, path, *args)
      super
      
      @receiver = receiver.receiver
      @receiver_script = receiver.to_script
    end

    def each(&block)
      IO.popen(@__shell__.system_env, to_script, open_mode) do |io|
	io.each &block
      end
    end
    
    def to_script
      @receiver_script + "|" +
	@command_path + @args.collect{|e| e.to_s}.join(" ")
    end
  end
end


class Object
  def reish_stat; self; end
end

    
  
