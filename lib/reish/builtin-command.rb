#
#   lib/reish/builtin-command.rb - 
#   	Copyright (C) 2014-2017 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
module Reish
  module Test; end
  class<<Test

    instance_eval{alias test_org test}

    TestMap = {}

    TestSuperCommands = ["A", "C", "G", "M", "O", "R", "S", "X", "W", 
      "b", "c", "d", "e", "f", "g", "k", "l", "o", "p", "r", 
      "s", "u", "w", "x", "z"]

    TestSuperCommands.each do |sub|
      TestMap[sub] = proc{|sh, f| test_org(sub, sh.expand_path(f))}
    end

    TestSuperCommands2 = ["=", ">", "<", "-"]
    TestSuperCommands2.each do |sub|
      TestMap[sub] = proc{|sh, f, g| test_org(sub, sh.expand_path(f), sh.expand_path(g))}
    end
    
    TestTestMap = {"L" => "l",  "a" => "e", "h" => "l", # from bash test
      "mtime<" => "<", "mtime>" => ">", "mtime=" => "=", 
      "eq" => "-", 
    }
    TestTestMap.each do |key, sub|
      TestMap[key] = TestMap[TestTestMap[key]]
    end
    
    TestFileCommands = ["absolute_path", "atime", "basename", "blockdev?", 
      "chardev?", "chmod", "chown", "ctime", "delete", "unlink", "directory?", 
      "dirname", "executable?", "executable_real?", "exist?", "exists?", 
      "expand_path", "extname", "file?", "fnmatch", "ftype", "grpownd?", 
      "identical?", "join", "lchmod", "lchown", "link", "lstat", "mtime", 
      "owned?", "path", "pipe?", "readable?", "readable_real?", "readlink",
      "realdirpath", "realpath", "rename", "setgid?", "setuid?", "size", 
      "size?", "socket?", "split", "stat", "sticky?", "symlink", "symlink?", 
      "truncate", "umask", "utime", "world_readble?", "world_writable?", 
      "writable?", "writable_real?", "zero?"]

    TestFileCommands.each do |sub|
      TestMap[sub] = proc{|sh, f| File.send(sub, sh.expand_path(f))}
    end

    TestFileStatCommands = ["blksize", "blocks", "dev", "dev_major", 
      "dev_miner", "gid", "ino", "mode", "nlink", "rdev", "rdev_major",
      "rdev_miner", "uid"]

    TestFileStatCommands.each do |sub|
      TestMap[sub] = proc{|sh, f| File.stat(sh.expand_path(f)).send(sub)}
    end

    TestMap["mtime<="] = proc{|sh, fn1, fn2| !test_org(?>, sh.expand_path(fn1), sh.expand_path(fn2))}
    TestMap["mtime>="] = proc{|sh, fn1, fn2| !test_org(?<, sh.expand_path(fn1), sh.expand_path(fn2))}

    ["atime", "ctime", "size"].each do |key|
      [">", ">=", "<", "<=", "="].each do |op|

	op1 = op
	op1 = "==" if op == "="
	TestMap[key+op] = eval "proc{|sh, f, g| File.#{key}(sh.expand_path(f)) #{op1} File.#{key}(sh.expand_path(g))}"
      end
    end

    TestMap["owner"] = proc{|sh, fn| 
      require "etc"
      Etc::getpwuid(File.stat(sh.expand_path(fn)).uid).name
    }
    TestMap["owner?"] = proc{|sh, fn, usr| 
      require "etc"
      ret = false
      begin
	pw = Etc::getpwnam(usr)
	ret = File.stat(sh.expand_path(fn)).uid == pw.uid
      rescue ArgumentError
      end
      ret
    }

    # Bash Test Command rests: "N","t"

    def test(sub, *args, &block)
      sh = Reish.current_shell
      if p = TestMap[sub]
	return p.call(sh, *args, &block)
      end
      if /^-([^-].+)/ =~ sub
	sub = $1
	if p = TestMap[sub]
	  return p.call(sh, *args, &block)
	end
      end
      raise NoMethodError, "undefined hyphen command -#{sub}" 
    end
  end

  module BuiltIn

    def command(name, *opts)
      sh = Reish::current_shell
      com = sh.search_command(self, name, *opts)
      Reish.Fail CommandNotFound, name unless com
      com
    end

    def chdir(path)
      Reish::current_shell.exenv.chdir(path)
    end
    
    alias cd chdir

    # kill [signame|-signum] [pid|jobid]...
    # kill signame|-signum 0|-1
    # kill signame|-signum -pid...
    def kill(sig, *pids, signal: nil)
      case sig
      when Integer
	case 
	when sig > 0
	  pids.unshift sig
	  sig = nil
	when  sig == 0
	  raise ArgumentError, "invarid first argument: 0"
	when sig < 0
	  if pids.empty?
	    raise ArgumentError, "have to specify pids."
	  end
	  sig = -sig
	end

      when /^-([0-9]+)$/
	sig = $1,to_i
      when /^-(.*)$/
	sig = $1
      when /^%([0-9]+)%/
	pids.unshift sig
	sig = nil
      end

      ppids = []
      jobs = []
      pids.each do |pid|
	case pid
	when Integer
	  ppids.push pid
	when /%([0-9]+)/
	  jobs.push $1.to_i
	else
	  raise ArgumentError, "invarid pid specs(%{pid})."
	end
      end

      if sig == nil && ppids.find{|p| p <= 0}
	raise ArgumentError, "have to specify signal when pid is 0 or minus."
      end

      if sig && signal
	raise ArgumentError, "double specify signal argument"
      end
      signal ||= sig
      signal ||= :SIGTERM

      unless jobs.empty?
	sh = Reish::current_shell
	sh.job_controller.kill_jobs(signal, *jobs)
      end
      unless ppids.empty?
	Process.kill signal, *ppids
      end
    end

#     def background_job(script=nil, &block)
#       sh = Reish::current_shell
#       sh.job_controller.start_job(false, script) do
# 	sh.signal_status(:IN_EVAL) do
# 	  sh.activate_command_search do
# 	    block.call
# 	  end
# 	end
#       end
#       nil
#     end

    def background_job(script=nil, &block)
      sh = Reish::current_shell
      sh.start_job(false, script, &block)
    end

    def self.def_command(name, klass)
      BuiltIn.module_eval %{
	def #{name}(*opts)
	  begin
	    return super unless Reish::active_thread?
	  rescue NoMethodError
	    raise NameError, "undefined local variable or method `#{name}' for \#{self}"
	  end
	  #{klass}.new(self, *opts)
	end
      }
    end

    class BuiltInCommand
      include Enumerable

      def initialize(receiver, *opt)
	@receiver = receiver
      end

      def reish_result
	to_a
      end
    end

    class Jobs<BuiltInCommand

      def each(&block)
	sh = BuiltIn::current_shell
	sh.job_controller.jobs.each &block
      end

      def reish_result
	sh = Reish::current_shell
	sh.job_controller.jobs
      end

      def reish_term
	sh = Reish::current_shell
	jobs = sh.job_controller.jobs
	if STDOUT.tty?
	  jobs.each_with_index do |job, idx|
	    puts "#{idx} #{job.info} " if job
	  end
	  nil
	else
	  jobs.each{|job| puts job.to_s}
	end
      end
    end

    class SampleLS<BuiltInCommand
      def initialize(receiver, path = nil)
	super

	path = Reish.current_shell.exenv.pwd unless path
	@path = path
      end

      def each(&block)
	for f in Dir.entries(@path)
	  block.call f
	end
      end

      def reish_term
	each do |f|
	  puts f
	end
      end
    end

    class SampleGrep<BuiltInCommand
      def initialize(receiver, reg)
	super

	@regex = reg
      end

      def each(&block)
	@receiver.each do |e|
	  block.call e if @regex =~ e
	end
      end
    end

# for reirb
#    def_command :jobs, Jobs
    def_command :sample_ls, SampleLS
    def_command :sample_grep, SampleGrep
  end
end

class Object
  include ::Reish::BuiltIn
end

