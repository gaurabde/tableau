# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2010 Tableau Software, Incorporated
#                    and its licensors. All rights reserved.
# Protected by U.S. Patent 7,089,266; Patents Pending.
#
# Portions of the code
# Copyright (c) 2002 The Board of Trustees of the Leland Stanford
#                    Junior University. All rights reserved.
# -----------------------------------------------------------------------
# common/ruby/lib/vizql/dll.rb
# -----------------------------------------------------------------------

require 'tabvizql'
require 'core_licenses'
require 'server_license_workgroup'

unless $vizql_startup_done
  h = AppConfig.vizqlserver.flatten

  #fix up some of the appconfig parameters to be in the form expected by
  #the server
  h['querylimit']             = h['querylimit'] * 1000
  h['pgsql.host']             = AppConfig.pgsql.host
  h['pgsql.port']             = AppConfig.pgsql.port
  h['logrotateinterval']      = (AppConfig.log.rotate == true) ? AppConfig.log.rotate_interval : 0
  h['logautoflush']           = AppConfig.vizqlserver.log.autoflush
  h['public']                 = AppConfig.public.enabled
  h['dataengine.exe_path']    = AppConfig.dataengine.exe_path
  h['dataengine.config_file'] = AppConfig.dataengine.config_dir + '/tdeserver_spawned.yml'
  h['service.app.mode']       = AppConfig["service.app.mode"]

  # not used by DLL and could cause confusion in the DLL logs because these keys
  # seem to be app specific
  h.delete('port')
  h.delete('log.mongrel_pid')
  h.delete('log.mongrel')
  h.delete('config.mongrel')
  h.delete('config.dir')
  h.delete('deploy.dir')
  h.delete('log.dir') # could be AppConfig[$TABLEAU_APP_NAME].log.dir, but unused

  # $TABLEAU_APP_NAME is either 'wgserver', 'backgrounder', or 'tabconsole'

  port = 0

  if $TABLEAU_APP_NAME == 'wgserver' || $TABLEAU_APP_NAME == 'backgrounder'
    port = AppConfig[$TABLEAU_APP_NAME].port + APP_PROC_NUM
  end

  h['instanceid']    = port
  h['tilecache.dir'] = h['tilecache.dir'] + "/#{port}"
  h['tilecache.url'].sub!('%PORT%', port.to_s)

  h['worker_id'] = AppConfig.worker_id

  if $TABLEAU_APP_NAME == 'backgrounder'
    h['querylimit'] = AppConfig.backgrounder.querylimit * 1000
    h['logid'] = "#{$TABLEAU_APP_NAME}_#{$BACKGROUNDER_PROC_NUM}"
    h['procid'] = $BACKGROUNDER_PROC_NUM
    # if this is the backgrounder running in 'data engine migrate' mode, change
    # the log file name so it's separate from the regular log file.
    h['logid'] = 'tde_migrate' if $backgrounder_migrate
  elsif $TABLEAU_APP_NAME == 'tabconsole'
    h['logid'] = "tabconsole"
    h['procid'] = 0
  else
    h['logid'] = "#{$TABLEAU_APP_NAME}_#{port}"
    h['procid'] = APP_PROC_NUM

    # wgserver operations with the DLL should be allowed to take as long as
    # an apache gateway timeout
    h['querylimit'] = AppConfig.gateway.timeout * 1000
  end

  # Determine if we have an OEM license
  license = ServerLicenseWorkgroup.instance
  h['oemlicense'] = license.is_oemlicense?
  #B35217 Change Maintenance status to orange when vizqlserver cannot retrieve license
  # Used isProcessLicensed global variable which will be set to false at startup.
  # If the flag is false, it's in an unlicensed state, else it's in a licensed state.
  $isProcessLicensed = false
  need_license = true
  delayed_retry(:tries=>20, :exceptions=>[LicensingNotReadyError]) do 
    begin
      need_license = license.need_license?
    rescue LicensingUninitializedError => e
      # Bug 48464 - calling this before the database is initialized is expected
    end
  end
  
  if !need_license
    h.merge!(license.data_source_capabilities)
    h.merge!(license.map_source_capabilities)
    #We retrieved the license(s) successfully, set it to true.
    $isProcessLicensed = true
  end
  # Determine if the license or server config has suppressed initial SQL.
  if license.no_initial_sql? || AppConfig['vizqlserver.initialsql.disabled']
    h['noinitialsql'] = 'true';
  end

  # Determine if we have 'guest branding' that requires displaying Tableau
  # branding for embedded views
  if !need_license && license.has_guest_branding?
    h['guestbranding'] = 'true';
  end

  # Build the server startup options table
  options = VizqlDll::StringOptionTable.new
  h.each_pair { |k,v| options.put(k.to_s, v.to_s) }

  VizqlDll::Vizql.ServerStartup options
  $vizql_startup_done = true
end

def global_vizql_dll_shutdown
  unless $vizql_shutdown_done
    VizqlDll::Vizql.ServerShutdown
    $vizql_shutdown_done = true
  end
end

# Removing these will cause a dll crash on exit. We must set both a SIGINT (aka Ctrl-C) handler as
# well as a general at_exit since backgrounder doesn't call exit on Ctrl-C, but wgserver does.
trap("SIGINT") {
  exit(true)
}

at_exit {
  global_vizql_dll_shutdown()
}
