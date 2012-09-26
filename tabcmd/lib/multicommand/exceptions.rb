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

module MultiCommand
  # ReportableError implies that the error is intended for user
  # messaging, and that a backtrace is not necessary.  See also
  # CommandHelpError if help output is desired along with the
  # reported message.
  class ReportableError < RuntimeError
  end

  # User authorization failure
  class AuthFailure < ReportableError
  end

  # This is a reportable error that should output the help for the
  # relevant command.  For example, bad command arguments or options
  # might raise this error.
  class HelpError < ReportableError
  end

  class ExternalCommandFailure < RuntimeError
    def initialize(output,status=$?.exitstatus)
      @output = output
      @status = status
    end
    attr_reader :output, :status
  end

  # This exception causes the application to exit with a specified
  # status
  class ExitWithStatus < RuntimeError
    def initialize(status)
      @status = status
    end
    attr_reader :status
  end
end
