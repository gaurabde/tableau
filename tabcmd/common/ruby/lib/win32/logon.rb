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

require 'java'
require 'jna.jar'
require 'platform.jar'

module Logon
  LOGON32_LOGON_NETWORK         = 3
  LOGON32_LOGON_NEW_CREDENTIALS = 9

  LOGON32_PROVIDER_DEFAULT  = 0
  LOGON32_PROVIDER_WINNT50  = 3

  class LogonError < StandardError
  end


  def self.with_logon(username, password, remote=false, wide=false, optional_domain = nil)
    password = '' if password.nil?

    # If we have a UPN style username, then domain should be nil,
    # otherwise extract the domain.  If no domain is present, set
    # domain to '.' to search the machine login only.  See LogonUser
    # documentation for details.
    domain, username = username.split('\\') if username.index('\\')
    if (wide)
      domain = optional_domain # basically this comes in as '\000' and seems to help.
    else
      domain ||= ('.' if username.index('@').nil?)
    end

    instance = com.sun.jna.platform.win32.Advapi32.INSTANCE

    token = com.sun.jna.platform.win32.WinNT::HANDLEByReference.new

    res = instance.LogonUser(username, domain, password,
                             remote ? LOGON32_LOGON_NEW_CREDENTIALS : LOGON32_LOGON_NETWORK,
                             remote ? LOGON32_PROVIDER_WINNT50 : LOGON32_PROVIDER_DEFAULT,
                             token)

    raise LogonError unless res

    ## service/configure.rb wants the user auth token to validate connection to extracts engine
    ## However I am unable to pass this through from Java.  Really, we might as well move that whole
    ## section into C++ since core does the connection attempt anyway.
    yield token.getValue

    return res
  end

  # Username may be domain-unqualified, in which case a system-local
  # auth is attempted.  A domain may be provided as 'DOMAIN\user' or
  # via a UPN-style 'user@fully.qualified.domain' name.
  def self.verify_credentials(username, password, wide = false, optional_domain = nil)
    with_logon(username, password, false, wide, optional_domain) do |token|
      return true
    end
  rescue LogonError
    return false
  end

end

class Tester
  def test
    puts %Q[expect_success is #{Logon.verify_credentials('workgroupadmin@tsi.lan','W0rkGr0up!')}]
    puts %Q[expect_success is #{Logon.verify_credentials('tsi.lan\\workgroupadmin','W0rkGr0up!')}]
    puts %Q[expect_fail is #{Logon.verify_credentials('workgroupadmin@tsi.lan','fnord')}]
  end
end
