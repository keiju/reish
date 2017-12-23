#
#   comp-cmd-proc.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "reish/reidline/lam-messenger"
require "reish/reidline/composite-messenger"

module Reish
  class CompCmdProc
    include CompAction

    def initialize(call = nil)
      @title = nil

      @call = call
      @tag2commands = {}

      @last_tag = nil

      @tag2candidates = nil
    end

    def tag(tag)
      @last_tag = tag
    end

    def add(*commands, tag: nil)
      if tag
	@last_tag = tag
      end

      if commands.size == 1 && commands.first.kind_of?(Array)
	commands = commands.first
      end

      unless commands.empty?
	if @tag2commands[@last_tag]
	  @tag2commands[@last_tag].concat commands
	else
	  @tag2commands[@last_tag] = commands
	end
      end
    end

    def candidates
      unless @call
	@tag2candidates = @tag2commands
	return self
      end

      case @call.name
      when IDToken, ID2Token
	@tag2candidates = {}
	@tag2commands.each do |tag, cmds|
	  cands = cmds.grep(/^#{@call.name.value}/)
	  @tag2candidates[tag] = cands unless cands.empty?
	end
      when nil
	@tag2candidates = @tag2commands
	return self
      end

      case @tag2candidates.inject(0){|s, (tag, commands)| s += commands.size}
      when 0
	return []
      when 1
	cmd = @tag2candidates.each_value.find{|cmds| cmds && !cmds.empty?}
	return cmd
      else
	# path throw
      end

      t_size = @call.name.value.size
      c_set = @tag2candidates.each_value.inject([]){|u, cmds| u.concat cmds}.sort
      match = c_set.last.chars
      c_set.each do |cmd|
	n_match = []
	match.each_with_index do |m, i|
	  break unless m == cmd[i]
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

    def message_to(editor)
      if @tag2candidates.keys.size == 1
	tag = @tag2candidates.keys.first
	pager = Reidline::LamMessenger.new(@tag2candidates[tag], title: tag)
      else
	pager = Reidline::CompositeMessenger.new
	
	@tag2candidates.each do |tag, cmds|
	  pager.push Reidline::LamMessenger.new(cmds, title: tag)
	end
      end
      editor.message pager: pager
    end

    def for_readline
      @tag2candidates.each_value.inject([]){|cands, cmds| cands.concat cmds}.sort.uniq
    end

  end

  def self.CompCmdProc(call=nil, &block)
    ccp = CompCmdProc.new(call)
    block.call(ccp)
    ccp.candidates
  end
end
