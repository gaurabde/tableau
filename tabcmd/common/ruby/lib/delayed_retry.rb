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

def delayed_retry(opts)
  defaults = { :tries => 3,
    :delay => 0.5, #base delay in seconds
    :max_interval => 10} #in seconds, use nil for no-limit
  opts = defaults.merge(opts)
  raise ArgumentError, "No exceptions specified" unless opts[:exceptions]
  tries = 0
  begin
    yield
  rescue *opts[:exceptions]
    tries += 1
    if tries <= opts[:tries]
      interval = opts[:delay]*(2.0**(tries-1))
      interval = opts[:max_interval] if opts[:max_interval] && interval > opts[:max_interval]
      sleep(interval)
      retry
    else
      raise
    end
  end
end
