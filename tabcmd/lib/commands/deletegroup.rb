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

class Deletegroup < MultiCommand::Command
  include Http_Util

  def initialize
    super
  end

  def doc
    <<EOM
Remove a group.
EOM
  end

  def usage
    "#{name} GROUPNAME [options]"
  end

  def deletegroup(name)
    logger.info "Removing group #{name} from the server..."
    request = Server.create_request("manual/destroy_by_name/groups", "Post")
    params = []
    params += [ text_to_multipart('group', name) ]
    params += [ text_to_multipart('format', 'xml') ]
    params += [ text_to_multipart('authenticity_token', Server.authenticity_token) ]
    request.set_multipart_form_data(params)
    Server.execute(request)
  end

  def run(opts,args)
    unless args.size > 0
      raise RuntimeError, "#{name} requires a group name."
    end

    Server.login

    run_each(:deletegroup, args)
  end
end
