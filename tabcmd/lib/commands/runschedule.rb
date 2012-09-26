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

class Runschedule < MultiCommand::Command
  include Http_Util

  def initialize
    super
  end

  def doc
    <<EOM
Run a schedule.

Runs any schedule that has name of <SCHEDULE> on the server.
EOM
  end

  def usage
    "#{name} SCHEDULE" 
  end

  def runschedule(schedule)
    request = Server.create_request("manual/run/schedules", "Post")
    params = []
    params += [ text_to_multipart('name', schedule) ]
    params += [ text_to_multipart('format', 'xml') ]
    params += [ text_to_multipart('authenticity_token', Server.authenticity_token) ]
    request.set_multipart_form_data(params)
    logger.info "Running schedule '#{schedule}'..."
    response = Server.execute(request)
    logger.info Server.display_error(response, false)
  end

  def run(opts,args)
    unless args.size > 0
      raise RuntimeError, "#{name} requires a schedule name."
    end

    Server.login

    run_each(:runschedule, args)
  end
end
