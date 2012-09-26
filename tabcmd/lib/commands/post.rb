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

class Post < MultiCommand::Command
  include Http_Util

  def initialize
    super
  end

  def doc
    <<EOM
Make a POST request to the server.
EOM
  end

  def list?
    false
  end

  def usage
    "#{name} url [options]"
  end

  def define_options(opts,args)
    @request_filename = nil
    @response_filename = nil

    opts.on("--request FILENAME",
            "File to send as the body of the POST request."
          ) do |filename|
      @request_filename = RelativePath.fix_path(filename)
    end
    opts.on("--response FILENAME",
            "Location to save the body of the response."
          ) do |filename|
      @response_filename = RelativePath.fix_path(filename)
    end

  end

  def post(relative)
    request = Server.create_request(relative, 'Post')
    if @request_filename
      request.body = File.open(@request_filename, 'rb') { |file| file.read }
    end
    params = []
    params += [ text_to_multipart('authenticity_token', Server.authenticity_token) ]
    request.set_multipart_form_data(params)

    logger.info "Sending #{relative} to the server..."
    # Don't signal errors because we want to write the response even if
    # it's an error -- there may be information in it.
    response = Server.execute(request, :signal_error => false )
    if @response_filename
      File.open(@response_filename, 'wb') { |file| file.write(response.body) }
    end
    unless response.is_a?( Net::HTTPSuccess )
      Server.display_error(response)
    end
  end

  def run(opts,args)
    unless args.size > 0
      raise RuntimeError, "#{name} requires a url."
    end

    Server.login
    
    run_each(:post, args)
  end
end
