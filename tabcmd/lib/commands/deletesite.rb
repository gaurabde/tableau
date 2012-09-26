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

require 'http_util'

class Deletesite < MultiCommand::Command
  include Http_Util

  def initialize
    super
  end

  def doc
    <<EOM
Delete a site.
EOM
  end

  def usage
    "#{name} SITENAME [options]"
  end

  def deletesite(name)
    logger.info "Removing site #{name} from the server..."
    request = Server.create_request("manual/delete/sites", "Post")
    params = []
    params += [ text_to_multipart('site_name', name) ]
    params += [ text_to_multipart('format', 'xml') ]
    params += [ text_to_multipart('authenticity_token', Server.authenticity_token) ]
    request.set_multipart_form_data(params)
    Server.execute(request)
  end

  def run(opts,args)
    unless args.size > 0
      raise RuntimeError, "#{name} requires a site name."
    end

    Server.login

    run_each(:deletesite, args)
  end
end
