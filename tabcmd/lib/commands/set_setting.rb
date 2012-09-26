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

require 'uri'
require 'net/http'

class SetSetting < MultiCommand::Command
  include Http_Util

  def initialize
    super
  end

  def name
    "set"
  end

  def doc
    <<EOM
Set a setting on the server.  Use !setting to turn a setting off.
EOM
  end

  def usage
    "#{name} setting [options]"
  end

  def set(setting)
    if setting[0] == '!'[0]
      val = 0
      setting = setting[1,setting.length - 1]
    else
      val = 1
    end
    request = Server.create_request("manual/prefs/set_setting?which=#{setting}&val=#{val}&format=xml", 'Post')

    params = []
    params += [ text_to_multipart('authenticity_token', Server.authenticity_token) ]
    request.set_multipart_form_data(params)

    logger.info "Setting #{setting} to #{val == 1 ? 'true' : 'false'}..."
    response = Server.execute(request)
    unless response.body == "success"
      logger.error "Unexpected response from server"
      logger.error response.body
    end
  end

  def run(opts,args)
    unless args.size > 0
      raise RuntimeError, "#{name} requires a setting name."
    end

    Server.login

    run_each(:set, args)
  end
end
