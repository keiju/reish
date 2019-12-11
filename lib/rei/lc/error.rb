#
#   reish/lc/error.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

require "e2mmap"

module REI

  module ERR

  # exceptions
    extend Exception2MessageMapper
    def_exception :UnrecognizedSwitch, "Unrecognized switch: %s"
    def_exception :NotImplementedError, "Need to define `%s'"
    def_exception :IllegalParameter, "Invalid parameter(%s)."
    
    def_exception :NoSuchJob, "No such job(%s)."
    def_exception :NoTargetJob, "No target job."

    def_exception :CantSetBinding, "Can't set binding to (%s)."
    def_exception :CantChangeBinding, "Can't change binding to (%s)."
    def_exception :UndefinedPromptMode, "Undefined prompt mode(%s)."

    def_exception :NotExistCurrentShell, "Not exist current shell."
    def_exception :NotExistCurrentJob, "Not exist current job."
    class InternalError<StandardError; end
  end
end
