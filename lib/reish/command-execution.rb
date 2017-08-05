#
#   command-executionjob.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

module Reish
  class CommandExecution
    def initialize(command)
      @command = command
      @job = Reish::current_job

      @pid = nil
      @pstat = :NULL
      @exit_status = nil

      @wait_mx = Mutex.new
      @wait_cv = ConditionVariable.new
    end

    attr_accessor :pid
    attr_reader :pstat
    attr_reader :exit_status

    def pstat=(stat)
      @wait_mx.synchronize do
	@pstat = stat
	@wait_cv.broadcast
      end
    end

    def set_exit_stat(stat, status)
      @wait_mx.synchronize do
	@pstat = stat
	@command.exit_status = status
	@wait_cv.broadcast
      end
    end

    def pstat_finish?
      @pstat == :EXIT || @pstat == :TERM
    end

    def pstat_stop?
      @pstat == :TSTP || @pstat == :TTIN || @pstat == :TTOU
    end

    def popen(mode, &block)
      @job.popen_exe(self, 
		     [@command.exenv.env, 
		       @command.command_path, 
		       *@command.command_opts], 
		     mode, 
		     @command.spawn_options,
		     &block)
    end

    
    def spawn
      @job.spawn_exe(self,
		     @command.exenv.env, 
		     @command.command_path, 
		     *@command.command_opts,
		     @command.spawn_options)
    end

    def wait
      @wait_mx.synchronize do
	until pstat_finish?
	  @wait_cv.wait(@wait_mx)
	end
      end
    end

    def wait_while_closing(io)
      io.close
      @wait_mx.synchronize do
	unless $?
	  @command.exit_status = @exit_status
	  return
	end
	@exit_status = $?
	@command.exit_status = @exit_status
	case 
	when @exit_status.signaled?
	  puts "CommandExecution: pid=#{@pid} was killed by signal #{@exit_status.termsig}" if Reish::debug_jobctl?
	  @pstat = :TERM
	when @exit_status.exited?
	  puts "CommandExecution: pid=#{@pid} exited normally. status=#{@exit_status.exitstatus}" if Reish::debug_jobctl?
	  @pstat = :EXIT
	end
	@wait_cv.broadcast
      end
    end

    def info
      "<#{@command.info}[#{@pid}](#{@pstat.id2name})>"
    end
  end

  class ShellExecution<CommandExecution
    def popen(open_mode, &block)
      @job.popen_exe(self,
		     @command.exenv.env, 
		     @command.to_script, 
		     open_mode, 
		     @command.spawn_options, 
		     &block)
    end

    def spawn
      @job.spawn_exe(self,
		     @command.exenv.env, 
		     @command.to_script, 
		     @command.spawn_options)
    end
  end
end
