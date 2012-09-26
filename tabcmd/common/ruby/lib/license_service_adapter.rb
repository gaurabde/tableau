# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2010 Tableau Software, Incorporated
# Patents Pending.
# -----------------------------------------------------------------------
#
# Adapter class in order to use the java licensing service


class LicensingUninitializedError < StandardError
end
class LicensingNotReadyError      < StandardError
end


class LicenseServiceAdapter
  java_import java.net.ConnectException;
  java_import java.util.Calendar
  java_import javax.persistence.PersistenceException
  java_import org.hibernate.exception.GenericJDBCException
  java_import com.tableausoftware.model.workgroup.util.LicenseRoleType
  java_import com.tableausoftware.model.workgroup.WorkgroupModelException
  java_import com.tableausoftware.model.workgroup.service.CoreLicensingUninitializedException
  java_import com.tableausoftware.model.workgroup.service.CoreLicensingNotReadyException
  


unless LicenseServiceAdapter.const_defined?('LICENSING_ROLE_MAP')
    LICENSING_ROLE_MAP = {
      :interactor => LicenseRoleType::INTERACTOR,
      :viewer     => LicenseRoleType::VIEWER,
      :guest      => LicenseRoleType::GUEST,
      :unlicensed => LicenseRoleType::UNLICENSED
    }
end

unless LicenseServiceAdapter.const_defined?('LICENSE_STATE')
    LICENSE_STATE = {
      License::LicenseState::NoLicense           => :no_license,
      License::LicenseState::TrialActive         => :trial_active,
      License::LicenseState::TrialExpired        => :trial_expired,
      License::LicenseState::GraceActive         => :grace_active,
      License::LicenseState::MaintExpiredTrialOK => :maint_expired_trial_ok,
      License::LicenseState::MaintExpired        => :maint_expired,
      License::LicenseState::LicenseOK           => :license_ok,
      License::LicenseState::LicenseExpired      => :license_expired,
      License::LicenseState::LicenseError        => :license_error
    }
end

unless LicenseServiceAdapter.const_defined?('REGISTRATION_FORM')
  REGISTRATION_FORM = {
    License::License::getRegFormNone      => :none,
    License::License::getRegFormEmail     => :email,
    License::License::getRegFormShort     => :short,
    License::License::getRegFormStandard  => :standard,
    License::License::getRegFormNoAddress => :no_addr,
    License::License::getRegFormLong      => :long
  }
end

  
  def initialize(license_service)
    @license_service = license_service
  end

  def get_max(role)
    @license_service.getMax(LICENSING_ROLE_MAP[role])
  end

  def total_allocated_cores
    begin
      @license_service.totalAllocatedCores()
    # Pass through all unknown Java exceptions
    rescue CoreLicensingNotReadyException => e
      msg = "total_allocated_cores NotReady recovery: #{e}"
      logger.error msg if logger
      puts msg if !logger
      raise LicensingNotReadyError.new("Core Licensing error: #{e}")
    rescue CoreLicensingUninitializedException => e
      raise LicensingUninitializedError.new("Core Licensing error: #{e}")
    end
  end

  def periodic_check(user_id = 0, force_fail = false, session_id = nil)
    return @license_service.periodicCheck(user_id, force_fail, session_id)
  end

  def lookup_capacities
    return @license_service.lookupCapacities()
  end

  ## GROUP: License and Registration state

  def license_state
    LICENSE_STATE[@license_service.getLicenseState()]
  end

  def warn_expiration?
    @license_service.warnExpiration()
  end

  def get_expiration
    self.class.convert_to_ruby_date(@license_service.getExpiration())
  end

  def get_maintenance_expiration
    self.class.convert_to_ruby_date(@license_service.getMaintenanceExpiration())
  end

  def get_registration_form
    REGISTRATION_FORM[@license_service.getRegistrationForm()]
  end

  def need_license?
    begin
      @license_service.needLicense()
    rescue CoreLicensingNotReadyException => e
      msg = "need_license? NotReady recovery: #{e}"
      logger.error msg if logger
      puts msg if !logger
      raise LicensingNotReadyError.new("Core Licensing error: #{e}")
    rescue CoreLicensingUninitializedException => e
      raise LicensingUninitializedError.new("Core Licensing error: #{e}")
    end
  end

  def need_valid_license?
    @license_service.needValidLicense()
  end

  def need_registration?
    @license_service.needRegistration()
  end

  def requests_registration?
    @license_service.requestsRegistration()
  end

  def no_periodic_check?
    @license_service.noPeriodicCheck()
  end

  def is_asr?
    return @license_service.isAsr()
  end

  def is_trial?
    return @license_service.isTrial()
  end

  def is_oemlicense?
    @license_service.isOemLicense()
  end

  def log_license_info
    @license_service.logLicenseInfo()
  end

  def is_core_license?
    @license_service.isCoreLicense()
  end

  def machine_cores
    @license_service.machineCores()
  end

  def capacity_cores
    @license_service.capacityCores()
  end

  def capacity_interactors
    @license_service.capacityInteractors()
  end

  def capacity_viewers
    @license_service.capacityViewers()
  end

  def has_guest_user?
    return @license_service.hasGuestUser()
  end

  def has_guest_branding?
    return @license_service.hasGuestBranding()
  end

  def no_initial_sql?
    return @license_service.isNoInitialSql()
  end

  def machine_cores_consistent
    return @license_service.machineCoresConsistent()
  end


  ## GROUP: license attribute inspectors

  def data_source_capabilities
    @license_service.getDataSourceCapabilities()
  end

  def map_source_capabilities
    @license_service.getMapSourceCapabilities()
  end


  ## GROUP: license activation

  def activate(serial)
    @license_service.activate(serial)
  end

  def return(serial)
    @license_service.returnLicense(serial)
  end

  def resync_licenses
    SetTmp.with_saved_tmp do
      @license_service.resyncLicenses()
    end
  end

  def activate_trial
    @license_service.activateTrial()
  end

  def activate_grace
    @license_service.activateGrace()
  end

  def activate_server_asr(s)
    @license_service.activateServerAsr(s)
  end

  def process_offline_activation_response(s)
    config_only = @license_service.processOfflineActivationResponse(s)
    if config_only
      msg = "Your license has been initialized. To complete the activation, " +
            "we need one more exchange. Please run Manage Product Keys again " +
            "and generate a second Activation request file to send to Tableau."
      logger.notice msg if logger
      puts msg if !logger
    end
  end

  def process_offline_return_response(s)
    @license_service.processOfflineReturnResponse(s)
  end

  def validate_license_database()
    begin
      @license_service.validateLicenseDatabase()
    rescue CoreLicensingNotReadyException => e
      msg = "validate_license_database NotReady recovery: #{e}"
      logger.error msg if logger
      puts msg if !logger
      raise LicensingNotReadyError.new("Core Licensing error: #{e}")
    rescue CoreLicensingUninitializedException => e
      raise LicensingUninitializedError.new("Core Licensing error: #{e}")
    end
  end

  def testing?
    return @license_service.isTesting()
  end

  def testing=(value)
    @license_service.setTesting(value)
  end

  def logger
    @logger
  end

  def set_logger(logger)
    @logger ||= logger
  end


  ## GROUP: Helpers
  
  def self.convert_to_ruby_date(java_calendar)
    return nil if (java_calendar.nil?)
    # Add one because calendar has 0 based indexing for months
    return Date.civil(java_calendar.get(Calendar::YEAR), java_calendar.get(Calendar::MONTH)+1, java_calendar.get(Calendar::DATE))
  end

  def self.convert_to_ruby_string(java_calendar)
    return nil if (java_calendar.nil?)
    # Add one because calendar has 0 based indexing for months
    return "#{java_calendar.get(Calendar::MONTH)+1}-#{java_calendar.get(Calendar::DATE)}-#{java_calendar.get(Calendar::YEAR)}"
  end

end
