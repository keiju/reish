#
#   lib/reish/builtin-command.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#
module Reish
  module Test; end
  class<<Test

    instance_eval{alias test_org test}

    TestMap = {}

    TestSuperCommands = ["A", "C", "G", "M", "O", "R", "S", "X", "W", 
      "b", "c", "d", "e", "f", "g", "k", "l", "o", "p", "r", 
      "s", "u", "w", "x", "z", "=", ">", "<", "-"]

    TestSuperCommands.each do |sub|
      TestMap[sub] = proc{|*args| test_org(sub, *args)}
    end
    
    TestTestMap = {"L" => "l",  "a" => "e", "h" => "l", # from bash teest
      "mtime<" => "<", "mtime>" => ">", "mtime=" => "=", 
      "eq" => "-", 
    }
    TestTestMap.each do |key, sub|
      TestMap[key] = proc{|*args| test_org(sub, *args)}
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
      TestMap[sub] = proc{|*args| File.send(sub, *args)}
    end

    TestFileStatCommands = ["blksize", "blocks", "dev", "dev_major", 
      "dev_miner", "gid", "ino", "mode", "nlink", "rdev", "rdev_major",
      "rdev_miner", "uid"]
    TestFileStatCommands.each do |sub|
      TestMap[sub] = proc{|*args| File.stat(args[0]).send(sub)}
    end
    
    TestProcs = {
      "mtime<=" => proc{|fn1, fn2| !test_org(?>, fn1, fn2)},
      "mtime>=" => proc{|fn1, fn2| !test_org(?<, fn1, fn2)},

      "atime>" => proc{|fn1, fn2| File.atime(fn1) > File.atime(fn2)},
      "atime>=" => proc{|fn1, fn2| File.atime(fn1) >= File.atime(fn2)},
      "atime<" => proc{|fn1, fn2| File.atime(fn1) < File.atime(fn2)},
      "atime<=" => proc{|fn1, fn2| File.atime(fn1) <= File.atime(fn2)},
      "atime=" => proc{|fn1, fn2| File.atime(fn1) == File.atime(fn2)},

      "ctime>" => proc{|fn1, fn2| File.ctime(fn1) > File.ctime(fn2)},
      "ctime>=" => proc{|fn1, fn2| File.ctime(fn1) >= File.ctime(fn2)},
      "ctime<" => proc{|fn1, fn2| File.ctime(fn1) < File.ctime(fn2)},
      "ctime<=" => proc{|fn1, fn2| File.ctime(fn1) <= File.ctime(fn2)},
      "ctime=" => proc{|fn1, fn2| File.ctime(fn1) == File.ctime(fn2)},

      "size>" => proc{|fn1, fn2| File.size(fn1) > File.size(fn2)},
      "size>=" => proc{|fn1, fn2| File.size(fn1) >= File.size(fn2)},
      "size<" => proc{|fn1, fn2| File.size(fn1) < File.size(fn2)},
      "size<=" => proc{|fn1, fn2| File.size(fn1) <= File.size(fn2)},
      "size=" => proc{|fn1, fn2| File.size(fn1) == File.size(fn2)},

      "owner" => proc{|fn| 
	require "etc"
	Etc::getpwuid(File.stat(fn).uid).name
      },

      "owner?" => proc{|fn, usr| 
	require "etc"
	ret = false
	begin
	  pw = Etc::getpwnam(usr)
	  ret = File.stat(fn).uid == pw.uid
	rescue ArgumentError
	end
	ret
      }
    }

    TestProcs.each do |key, sub|
      TestMap[key] = proc{|*args| sub.call *args}
    end

    # Bash Test Command rests: "N","t"

    def test(sub, *args, &block)
      unless p = TestMap[sub]
	raise NoMethodError, "undefined hyphen command -#{sub}"
      end
      p.call(*args, &block)
    end
  end
end

