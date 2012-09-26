# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2010 Tableau Software, Incorporated
# Patents Pending.
# -----------------------------------------------------------------------

# Common licensing functionality for tabadmin, vqlweb and wgapp

require 'singleton'
require 'java'
require 'tab-license-dll.jar'
License = com.tableausoftware.license.dll

# module License
#  %w[License OEMInfo Product Criteria CachingVerifier ServerVerifierStrategy
#     NoLicenseException COleDateTime Verifier LicenseInfoPtr Exception
#     RegistrationException ActivationException].each do |symbol|
#     java_import "com.tableausoftware.license.dll.#{symbol}"
#   end
# end

require 'core_licenses'

# CLASS ServerLicense
# Lazy-loaded static singleton containing licensing state and logic
class ServerLicense
  def self.instance
    # B27027, B29525: Address major performance problems with license checks on Server.
    # The Singleton instance of ServerLicenseHelper *must* be retained or it will be
    # garbage collected.
    @@inst ||= ServerLicenseHelper.instance
  end

  private_class_method :new
end

## CLASS ServerLicenseHelper
## Helper class for ServerLicense using thread-safe Singleton
class ServerLicenseHelper
  include Singleton

  ## GROUP: Static license files (ASRs)

  ## try to get dev-tree server and war-file-server to both work
  dev_tree_path = File.dirname(__FILE__) + '../../../../wgapp/lib/'
  if File.exists?(File.expand_path(dev_tree_path + 'server_trial.asr'))
    ASR_BASE_PATH = dev_tree_path
  else
    ASR_BASE_PATH = File.dirname(__FILE__) + '../../../../lib/'
  end

  TRIAL_ASR = File.read(File.expand_path(ASR_BASE_PATH+'server_trial.asr'))
  INITIAL_ASR = File.read(File.expand_path(ASR_BASE_PATH+'initializer.asr'))

  ## GROUP: initialization
  def setup(cfg, logfile_base, opts = nil)
    @cfg = cfg
    @opts = opts
    @logfile = "#{@cfg.licensing.log.dir}/#{logfile_base}_lic.log"
    # B39472: When getting license, allow trying multiple times with sleeps between.
    # Default to 1 try, and no sleeps.
    @tries = 1
    @sleep_between = 0
    @random_extra_sleep = 0
    @tries = @cfg["licensing.tries"].to_i if @cfg["licensing.tries"]
    # You have to try to get a license at least once
    if @tries <= 0
      @tries = 1
    end
    @sleep_between = @cfg["licensing.sleep_between_tries"].to_f if @cfg["licensing.sleep_between_tries"]
    @random_extra_sleep = @cfg["licensing.random_extra_sleep"].to_f if @cfg["licensing.random_extra_sleep"]
  end


  ## GROUP: license qualifications

  # Returns true if this machine cannot aquire a usable license
  #
  def need_license?
    return true if need_valid_license?
    # Core licensing checks: if no license is allocated, try to acquire one
    if ( is_core_license? )
      # No need to acquire a license if we already have a valid core license record
      return false if CoreLicenses.is_licensed?(machine_ip, machine_cores)

      # B47647 - Relicense all workers if there is a licensing issue in HA
      CoreLicenses.purge_all if is_server_ha_enabled?

      # Attempt to acquire a license
      has_license = CoreLicenses.acquire_license(machine_ip, machine_cores, capacity_cores)

      # B28530 - Ensure the primary machine gets priority for acquiring licenses. If
      # no capacity is available, purge existing allocations and try again.
      if ( !has_license && machine_is_primary_server )
        CoreLicenses.purge_all
        has_license = CoreLicenses.acquire_license(machine_ip, machine_cores, capacity_cores)
      end
      # License is needed if we couldn't acquire a core license record
      return true if !has_license

      # Core license acquisition succeeded, reset the periodic refresh clock
      reset_core_refresh
      return false
    end

    return false
  end

  # Returns true if this machine cannot access a usable license
  # from Trusted Storage (potentially on the primary) for inspecting
  # license vendor string attributes.
  def need_valid_license?
    return true if no_license?
  end

  # Returns true if the server needs registration in order to run
  #
  def need_registration?
    check_registration(true)
  end

  # Returns true if the server would like registration, but doesn't
  # need it to run
  def requests_registration?
    check_registration(false)
  end


  ## GROUP: accessors

  def no_periodic_check?
    need_valid_license? ? false : info.get_no_periodic_check
  end

  def is_asr?
    return verifier.is_asr
  end

  def is_trial?
    return verifier.is_trial
  end

  def is_oemlicense?
    verifier.IsOEMLicense
  end

  def log_license_info
    verifier.log_license_info
  end

  def is_core_license?
    need_valid_license? ? false : capacity_cores > 0
  end

  def capacity_cores
    need_valid_license? ? 0 : info.get_licensed_cores
  end

  def capacity_interactors
    need_valid_license? ? 0 : info.get_licensed_interactors
  end

  def capacity_viewers
    need_valid_license? ? 0 : info.get_licensed_viewers
  end

  def has_guest_user?
    return !need_valid_license? && info.has_guest_user
  end

  def has_guest_branding?
    return !need_valid_license? && info.has_guest_branding
  end

  def no_initial_sql?
    return !need_valid_license? && info.get_no_initial_sql
  end


  ## GROUP: license attribute inspectors

  def data_source_capabilities
    if info.get_attribute( License::License::getAttrDCStd ) == License::License::getValueCustom
      {
        License::License::getAttrDCStd => License::License::getValueCustom,
        License::License::getAttrDCCap => info.get_attribute( License::License::getAttrDCCap )
      }
    else
      { License::License::getAttrDCStd => 'default' }
    end
  end

  def map_source_capabilities
    if info.get_attribute( License::License::getAttrMapStd ) == License::License::getValueCustom
      {
        License::License::getAttrMapStd => License::License::getValueCustom,
        License::License::getAttrMapCap => info.get_attribute( License::License::getAttrMapCap )
      }
    else
      { License::License::getAttrMapStd => 'default' }
    end
  end


  ## GROUP: Core licensing
  #  Periodic license refresh logic to ensure the timestamp record for this
  #  machine is periodically updated to indicate it's still being used
  @@core_refresh_delay = 60*60
  @@last_core_refresh_check = Time.now

  def reset_core_refresh(time=nil)
    time = Time.now if time.nil?
    @@last_core_refresh_check = time
  end

  def periodic_core_refresh
    if Time.now >= @@last_core_refresh_check + @@core_refresh_delay
      reset_core_refresh
      CoreLicenses.refresh_license(machine_ip, machine_cores)
    end
  end

  def machine_ip
    @worker_ip ||= @cfg.worker.hosts.split(/, */)[@cfg.worker_id]
  end

  # machine_cores
  # Detect the number of machine cores, and determine if there are inconsistencies
  # across APIs which use various techniques for counting cores. This will allow
  # us to warn the user about necessary hotfixes. (B28543)
  def machine_cores
    return 0 if machine_needs_no_license
    @machine_cores ||= verifier.detect_machine_core_count()
  end

  # machine_cores_consistent
  # Determine if the machine core counting logic produces consistent results across
  # APIs which use various techniques for counting cores.
  def machine_cores_consistent
    return true if machine_needs_no_license
    @machine_cores_consistent ||= verifier.detect_machine_core_count_consistency()
  end

  def machine_is_primary_server
    @cfg.worker_id == 0
  end

  def machine_needs_no_license
    @cfg.worker_id == 0 && @opts && @opts.nolicense
  end
  
  def is_server_ha_enabled?
    @cfg.worker_id == 0 && @opts && @opts.ha
  end

  ## GROUP: Testing

  @@testing = false
  def testing?
    @@testing
  end

  def testing=(value)
    clear_cached_license if @@testing != value
    @@testing = value
  end

  # This method clears out the current verifier so that the next
  # request will reset it.
  def clear_cached_license
    @verifier = nil
  end


  protected

  ## GROUP: Licensing objects from backend via tablic

  # The criteria description for TableauServer licenses
  #
  def criteria
    product = "#{'Test' if testing?}#{License::Product.getSERVER}"
    app_ver = @cfg.version.rstr.split('.')[0]
    License::OEMInfo.set_app_version( app_ver.to_i )
    oemname = License::OEMInfo.Singleton(true).OEMName()
    License::Criteria.new(product, oemname, @cfg.version.current.to_s,
                          @cfg.version.build.date.to_s, @cfg.version.rstr)
  end

  # The criteria description for TableauServerCapacity licenses
  #
  def capacity_criteria
    product = "#{'Test' if testing?}#{License::Product.getCAPACITY}"
    app_ver = @cfg.version.rstr.split('.')[0]
    License::OEMInfo.set_app_version( app_ver.to_i )
    oemname = License::OEMInfo.Singleton(true).OEMName()
    License::Criteria.new(product, oemname, @cfg.version.current.to_s,
                          @cfg.version.build.date.to_s, @cfg.version.rstr)
  end

  # The caching interface to our backend ServerVerifierStrategy
  #
  def verifier
    return @verifier if @verifier
    @verifier ||= License::CachingVerifier.create_from_strategy(@logfile.to_s, criteria, strategy)
    tries = 0
    while tries < @tries
      return @verifier if !@verifier.need_license
      tries += 1
      if tries < @tries && (@sleep_between > 0 || @random_extra_sleep > 0)
        sleep @sleep_between + rand * @random_extra_sleep
      end
    end
    # Text is  not IDS_LICENSE_VIEW_NONE 
    # B49405 This  warning was misleading when activating licenses.  added "pre-existing"
    logger.warn "No pre-existing licenses found." if defined?(logger) && !logger.nil?
    return @verifier
  end

  # The underlying ServerVerifierStrategy
  #
  def strategy
    @strategy ||= License::ServerVerifierStrategy.create(TRIAL_ASR, INITIAL_ASR,
                                       @cfg.licensing.file.to_s, @cfg.licensing.app.lmreread.to_s,
                                       @cfg.public.enabled,
                                       @cfg.saas.enabled)
  end

  def no_license?
    verifier.need_license
  end

  # The confirmed license information object, via the backend License::Info
  #
  def info
    if need_valid_license?
      verifier.log_license_info
      raise License::NoLicenseException.new
    end
    verifier.get_license_state.m_activeLicense
  end


  ## GROUP: Helpers

  # Returns true if registration is needed.  If consider_grace is true, being
  # in a grace period means that registration is not needed
  #
  def check_registration(consider_grace)
    lic_state = verifier.get_license_state
    # If we are in a grace period, we don't need registration to run
    return false if consider_grace and
      lic_state.m_state == License::LicenseState::GraceActive

    return verifier.needs_registration
  end
end
