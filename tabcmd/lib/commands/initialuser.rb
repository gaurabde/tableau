# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (C) 2010    Tableau Software.
# Patents Pending.
# -----------------------------------------------------------------------

require 'uri'
require 'net/http'

class Initialuser < MultiCommand::HiddenCommand
  include Http_Util

  def initialize
    super
  end

  def doc
    <<EOM
Set the initial user on a newly installed or reset server.
EOM
  end

  def usage
    "#{name} username password friendly_name"
  end

  # Yes, the crazy formatting of the here-is text below is intentional
  # optparse automatically indents the first but not subsequent lines
  # of the help.
  def define_options(opts,args)
    @username  = nil
    @password = nil
    @friendly_name = nil

    opts.on("-f",
            "--friendly friendly",
            <<EOM
friendly name
EOM
          ) do |friendly|
      @friendly_name = friendly
    end

    opts.on("-e",
            "--email email",
            <<EOM
email address
EOM
          ) do |email|
      @email = email
    end
  end

  def set_initialuser(args)
    Server.get_startup_auth_token

    params = []
    params << "format=xml"
    params << "startup1[name]=#{Server.username}"
    params << "startup1[email]=#{@email}"
    params << "startup1[password]=#{Server.password}"
    params << "startup1[password_confirmation]=#{Server.password}"
    params << "startup1[friendly_name]=#{Tabcmd.encode_id(@friendly_name)}"
    params << "authenticity_token=#{Server.authenticity_token}"
    request = Server.create_request("/manual/startup/1?#{params.join('&')}", "Post")

    params = []
    params += [ text_to_multipart('authenticity_token', Server.authenticity_token) ]
    request.set_multipart_form_data(params)

    response = Server.execute(request)
    logger.info Server.display_error(response, false) # Using display_error to display successful messages as well.
  end

  def run(opts,args)
    unless Server.password && Server.username && @friendly_name
      raise RuntimeError, "#{name} requires a username, password, and friendly name."
    end
    unless Server.username
      raise RuntimeError, "--username argument is mandatory for #{name}"
    end
    unless @friendly_name
      raise RuntimeError, "--friendly_name argument is mandatory for #{name}"
    end
    unless Server.password
      raise RuntimeError, "--password argument is mandatory for #{name}"
    end

    set_initialuser(args)
  end
end
