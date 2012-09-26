# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2011 Tableau Software, Incorporated
#                    and its licensors. All rights reserved.
# Protected by U.S. Patent 7,089,266; Patents Pending.
#
# Portions of the code
# Copyright (c) 2002 The Board of Trustees of the Leland Stanford
#                    Junior University. All rights reserved.
# -----------------------------------------------------------------------

require 'ffi'

module MSVCRT
  extend FFI::Library

  ffi_lib "msvcrt"
  ffi_convention :stdcall

  attach_function :_putenv, [:string], :int

  def self.putenv(name, val)
    ENV[name] = val
    _putenv("#{name}=#{val}")
  end

end
