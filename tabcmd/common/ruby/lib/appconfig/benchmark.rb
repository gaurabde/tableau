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

require 'appconfig'
require 'customization'
APPCONFIG_CLOPT_DEFAULT = ENV['WG_TEST_SERVICE'] || 'test'

begin
  require 'appconfig/clopt'
rescue NoConfiguration => e
  $stderr.puts e.to_s
  $stderr.puts "Is the \'#{AppConfig.config_name}\' service initialized?"
  exit 1
end
