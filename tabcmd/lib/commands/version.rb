# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2011 Tableau Software, Incorporated
# Patents Pending.
# -----------------------------------------------------------------------

class Version < MultiCommand::Command
  def initialize
    super
  end

  def doc
    <<EOM
Print version information.
EOM
  end

  def usage
    "#{name}"
  end

  def run(opts,args)
    # Error handling is all in Server.login
    logger.info "Tableau Server Command Line Utility -- Version #{ProductVersion.full.str}"
  end
end
