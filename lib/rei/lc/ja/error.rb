# -*- coding: utf-8 -*-
#   irb/lc/ja/error.rb -
#   	by Keiju ISHITSUKA(keiju@ruby-lang.org)

require "e2mmap"

module REI
  module ERR
    # exceptions
    extend Exception2MessageMapper
    def_exception :UnrecognizedSwitch, 'スイッチ(%s)が分りません'
    def_exception :NotImplementedError, '`%s\'の定義が必要です'
    def_exception :IllegalParameter, 'パラメータ(%s)が間違っています.'
    
    def_exception :NoSuchJob, 'そのようなジョブ(%s)はありません.'
    def_exception :NoTargetJob, '対象となるジョブはありません.'

    def_exception :CantSetBinding, 'バインディング(%s)に設定できません.'
    def_exception :CantChangeBinding, 'バインディング(%s)に変更できません.'
    def_exception :UndefinedPromptMode, 'プロンプトモード(%s)は定義されていません.'
    def_exception :NotExistCurrentShell, 'カレントシェルがありません.'
    def_exception :NotExistCurrentJob, 'カレントジョブがありません.'

  end
end
