# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2010 Tableau Software, Incorporated
# Patents Pending.
# -----------------------------------------------------------------------

# Licensing mixins for advanced operations and testing

require 'licensing'
require 'singleton'

## CLASS ServerLicenseActivation
## Create a singleton ServerLicense extended with with Activation mixins
##
class ServerLicenseActivation
  def self.instance
    # B27027, B29525: Address major performance problems with license checks on Server.
    # The Singleton instance of ServerLicenseActivationHelper *must* be retained or
    # it will be garbage collected.
    @@inst ||= ServerLicenseActivationHelper.instance
    @@inst.get_server_license
  end

  private_class_method :new
end

## CLASS ServerLicenseActivationHelper
## Helper class for ServerLicenseActivation using thread-safe Singleton
## Create a singleton ServerLicense and extend with with Activation mixins
##
class ServerLicenseActivationHelper
  include Singleton

  def initialize
    @server_license = ServerLicense.instance
    @server_license.extend(ServerLicenseActivationMixins)
  end

  def get_server_license
    @server_license
  end
end

## CLASS License::COleDateTime
## Extend COleDateTime with license-friendly datetime/string converters
##
class License::COleDateTime
  def to_date
    Date.civil(get_year,get_month,get_day)
  end

  def to_s
    "#{get_month}-#{get_day}-#{get_year}"
  end
end

## MODULE ServerLicenseActivationMixins
## Define the functionality mixins for licensing activation,
## license state and registration state.
##
module ServerLicenseActivationMixins
  ## GROUP: licensing activation operations

  def activate(serial)
    verifier.activate(serial)
  end

  def return(serial)
    verifier.return(serial)
  end

  def resync_licenses
    SetTmp.with_saved_tmp do
      verifier.resync_all
    end
  end

  def activate_trial
    unless [:trial_active, :trial_expired, :maint_expired].include?(license_state)
      verifier.activate_trial
    end
  end

  def activate_grace
    unless license_state == :grace_active
      verifier.activate_grace
    end
  end

  def activate_server_asr(s)
    verifier.activate_server_asr(s)
  end

  def process_offline_activation_response(s)
    config_only = verifier.process_offline_activation_response(s)
    if config_only
      msg = "Your license has been initialized. To complete the activation, " +
            "we need one more exchange. Please run Manage Product Keys again " +
            "and generate a second Activation request file to send to Tableau."
      logger.notice msg if logger
      puts msg if !logger
    end
  end

  def process_offline_return_response(s)
    verifier.process_offline_return_response(s)
  end


  ## GROUP: License and Registration state

  def license_state
    LICENSE_STATE[verifier.get_license_state.m_state]
  end

  def warn_expiration?
    begin
      # We always warn, so pass -1 as the last time we warned.
      return info.should_warn(-1)
    rescue License::NoLicenseException
      false
    end
  end

  def get_expiration
    begin
      if info.is_permanent
        nil
      else
        info.get_expiration.to_date
      end
    rescue License::NoLicenseException
      nil
    end
  end

  def get_maintenance_expiration
    begin
      info.get_maintenance_expiration.to_date
    rescue License::NoLicenseException
      nil
    end
  end

  def get_registration_form
    state = verifier.get_license_state
    lic = state.m_activeLicense
    if lic.nil?
      return :none
    else
      return REGISTRATION_FORM[lic.get_reg_form]
    end
  end


  ## GROUP: License and Registration identifiers

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

  REGISTRATION_FORM = {
    License::License::getRegFormNone      => :none,
    License::License::getRegFormEmail     => :email,
    License::License::getRegFormShort     => :short,
    License::License::getRegFormStandard  => :standard,
    License::License::getRegFormNoAddress => :no_addr,
    License::License::getRegFormLong      => :long
  }


  ## GROUP: Logger
  def logger
    @logger
  end

  def set_logger(logger)
    @logger ||= logger
  end

end
