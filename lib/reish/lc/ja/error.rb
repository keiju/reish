# -*- coding: utf-8 -*-
#   irb/lc/ja/error.rb -
#   	by Keiju ISHITSUKA(keiju@ruby-lang.org)

require "e2mmap"

module Reish
  # exceptions
  extend Exception2MessageMapper
  def_exception :UnrecognizedSwitch, 'スイッチ(%s)が分りません'
  def_exception :NotImplementedError, '`%s\'の定義が必要です'
  def_exception :CantReturnToNormalMode, 'Normalモードに戻れません.'
  def_exception :IllegalParameter, 'パラメータ(%s)が間違っています.'
  def_exception :ReishAlreadyDead, 'Irbは既に死んでいます.'
  def_exception :IrbSwitchedToCurrentThread, 'カレントスレッドに切り替わりました.'
  def_exception :NoSuchJob, 'そのようなジョブ(%s)はありません.'
  def_exception :NoTargetJob, '対象となるジョブはありません.'
  def_exception :CantShiftToMultiReishMode, 'multi-irb modeに移れません.'
  def_exception :CantSetBinding, 'バインディング(%s)に設定できません.'
  def_exception :CantChangeBinding, 'バインディング(%s)に変更できません.'
  def_exception :UndefinedPromptMode, 'プロンプトモード(%s)は定義されていません.'
  def_exception :NotExistCurrentShell, 'カレントシェルがありません.'
  def_exception :NotExistCurrentJob, 'カレントジョブがありません.'
  def_exception :CommandNotFound, "コマンドが見つかりません(%s)"

  def_exception :ParserComplSupp, "Parser completion support exception."
  def_exception :ParserClosingSupp, "Parser closing support exception."
  def_exception :ParserClosingEOFSupp, "Parser closing support exception."
end
