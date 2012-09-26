# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2011 Tableau Software, Incorporated
#                    and its licensors. All rights reserved.
# Protected by U.S. Patent 7,089,266; Patents Pending.
#
# -----------------------------------------------------------------------

# refactored from stdout_to_file for non-command-line-use
# moved to common to work with warbler/tomcat

def map_streams_to_file(streams, outfile)
  if outfile && streams && !streams.empty?
    unless File.exist?(outfile)
      FileUtils.mkdir_p(File.dirname(outfile)) rescue nil
    end
    logfile = File.open(outfile, 'a')

    logfile.sync = true

    streams.each do |io|
      io.reopen(logfile)
    end
  end
end
