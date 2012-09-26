# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2012 Tableau Software, Incorporated
#                    and its licensors. All rights reserved.
# Protected by U.S. Patent 7,089,266; Patents Pending.
#
# Portions of the code
# Copyright (c) 2002 The Board of Trustees of the Leland Stanford
#                    Junior University. All rights reserved.
# -----------------------------------------------------------------------

require 'uri'
require 'net/http'

class Deleteproject < MultiCommand::Command
  include Http_Util

  def initialize
    super
  end

  def doc
    <<EOM
Deletes a project.
EOM
  end

  def usage
    %Q{#{name} <project_name>}
  end

  def deleteproject(name)
    logger.info "Deleting project #{@name} on the server..."
    request = Server.create_request("manual/projects/#{URI.encode(URI.encode(name))}", "Delete")
    params = [ ]
    params += [ text_to_multipart('format', 'xml') ]
    params += [ text_to_multipart('authenticity_token', Server.authenticity_token) ]
    request.set_multipart_form_data(params)
    Server.execute(request)
  end

  def run(opts,args)
    unless args.size > 0
      raise RuntimeError, "#{name} requires a project name."
    end

    Server.login

    run_each(:deleteproject, args)
  end
end
