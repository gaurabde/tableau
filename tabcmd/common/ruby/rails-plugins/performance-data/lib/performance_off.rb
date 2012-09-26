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
#
# -----------------------------------------------------------------------
# performance_data/lib/performance_off.rb
# -----------------------------------------------------------------------

require 'performance_models'

module PerformanceOff

  def on?
    false
  end
  
  def connect(config)
  end

  def write_tds( path, config )
    begin
      File.delete( path )
    rescue
    end
  end

end
