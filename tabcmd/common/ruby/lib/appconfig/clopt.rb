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

APPCONFIG_CLOPT_DEFAULT = 'dev' unless defined?(APPCONFIG_CLOPT_DEFAULT)

if ['-c','--config-name'].include?(ARGV[0])
  ARGV.shift
  configuration_name = ARGV.shift
end
configuration_name ||= ENV["WG_SERVICE"] || ENV["WG_TEST_SERVICE"] || java.lang.System.get_property("wgserver.service")

using_default = false
if (configuration_name.nil? || configuration_name.empty?)
  using_default = true
end
configuration_name ||= APPCONFIG_CLOPT_DEFAULT


begin
  AppConfigManager.load_by_name(configuration_name)
rescue
  raise unless using_default
end

begin
AppCustomizationManager.load_by_name(configuration_name)
rescue
  raise unless using_default
end
