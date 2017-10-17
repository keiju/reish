#
#   reish/lc/error.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "e2mmap"

module Reish

  # exceptions
  extend Exception2MessageMapper
  def_exception :UnrecognizedSwitch, "Unrecognized switch: %s"
  def_exception :NotImplementedError, "Need to define `%s'"
  def_exception :CantReturnToNormalMode, "Can't return to normal mode."
  def_exception :IllegalParameter, "Invalid parameter(%s)."
  def_exception :ReishAlreadyDead, "Reish is already dead."
  def_exception :ReishSwitchedToCurrentThread, "Switched to current thread."
  def_exception :NoSuchJob, "No such job(%s)."
  def_exception :NoTargetJob, "No target job."
  def_exception :CantShiftToMultiReishMode, "Can't shift to multi reish mode."
  def_exception :CantSetBinding, "Can't set binding to (%s)."
  def_exception :CantChangeBinding, "Can't change binding to (%s)."
  def_exception :UndefinedPromptMode, "Undefined prompt mode(%s)."

  def_exception :NotExistCurrentShell, "Not exist current shell."
  def_exception :NotExistCurrentJob, "Not exist current job."
  def_exception :CommandNotFound, "Command not found(%s)"

  def_exception :ParserComplSupp, "Parser completion support exception."
  def_exception :ParserClosingSupp, "Parser closing support exception."
  def_exception :ParserClosingEOFSupp, "Parser closing support exception."

  class InternalError<StandardError; end
end
