# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (C) 2008-9    Tableau Software.
# Patents Pending.
# -----------------------------------------------------------------------

require 'uri'
require 'net/http'

class Listsites < MultiCommand::Command
  include Http_Util

  def initialize
    super
  end

  def doc
    <<EOM
Lists sites for user.
EOM
  end

  def usage
    "#{name} [options]"
  end
  
  def listsites
    logger.info "Listing sites for user #{Server.username}..."
    request = Server.create_request("manual/list/sites")
    params = []
    params += [ text_to_multipart('format', 'xml') ]
    params += [ text_to_multipart('authenticity_token', Server.authenticity_token) ]
    request.set_multipart_form_data(params)
    response = Server.execute(request)
    xml = REXML::Document.new(response.body)
    message = ""
    xml.elements.each("sites/site") {
      |e| message += "\n\nNAME: #{e.elements["name"].text} \nSITEID: \"#{e.elements["url_namespace"].text}\""
    }
    logger.info message
  end

  def run(opts,args)

    Server.login

    listsites
  end
end