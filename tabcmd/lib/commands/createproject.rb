# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2010 Tableau Software, Incorporated
#                    and its licensors. All rights reserved.
# Protected by U.S. Patent 7,089,266; Patents Pending.
#
# Portions of the code
# Copyright (c) 2002 The Board of Trustees of the Leland Stanford
#                    Junior University. All rights reserved.
# -----------------------------------------------------------------------

require 'uri'
require 'net/http'

class Createproject < MultiCommand::Command
  include Http_Util

  def initialize
    super
  end

  def doc
    <<EOM
Create a project.
EOM
  end

  def usage
    %Q{#{name} --name=<name> --description=<description>}
  end

  def define_options(opts,args)
    @name = nil
    @description = nil

    opts.on("-n",
            "--name name",
            <<EOM
name of project
EOM
          ) do |name|
      @name = name
    end

    opts.on("-d",
            "--description description",
            <<EOM
email address
EOM
          ) do |description|
      @description = description
    end
  end


  def createproject(*args)
    logger.info "Creating project #{@name} on the server..."
    request = Server.create_request("manual/create/projects", "Post")
    params = []
    params += [ text_to_multipart('project', @name) ]
    params += [ text_to_multipart('description', @description) ] unless (@description.nil? || @description.empty?)
    params += [ text_to_multipart('format', 'js') ]
    params += [ text_to_multipart('authenticity_token', Server.authenticity_token) ]
    request.set_multipart_form_data(params)
    Server.execute(request)
  end

  def run(opts,args)
    unless @name && @description
      raise RuntimeError, "#{name} requires a project name and description"
    end

    Server.login

    createproject(args)
  end
end
