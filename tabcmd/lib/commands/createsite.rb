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

class Createsite < MultiCommand::Command
  include Http_Util

  def initialize
    super
  end

  def doc
    <<EOM
Create a site.
EOM
  end

  def usage
    "#{name} SITENAME [options]"
  end

  def define_options(opts,args)

    opts.on("-r",
      "--url ",
      <<EOM
URL namespace of site.
EOM
    ) do |url|
      @url_namespace = url
    end

    opts.on("--user-quota ",
      <<EOM
Maximum site users.
EOM
    ) do |quota|
      @user_quota = quota
      if !@user_quota.empty?
        @has_user_quota = 'true'
      else
        @has_user_quota = 'false'
      end
    end

    opts.on( "--[no-]content-mode",
      <<EOM
Allow [or deny] content administrator from user management on site.
EOM
    ) do |val|
      if val
        @content_admin_mode = '2'
      else
        @content_admin_mode = '1'
      end
    end
  end

  def createsite(name)
    logger.info "Creating site #{name} on the server..."
    request = Server.create_request("manual/create/sites", "Post")
    url = (@url_namespace.nil? ? name : @url_namespace)
    params = []
    params += [ text_to_multipart('site_name', name) ]
    params += [ text_to_multipart('url_namespace', url) ]
    params += [ text_to_multipart('user_quota', @user_quota) ] if @user_quota
    params += [ text_to_multipart('has_user_quota', @has_user_quota) ] if @has_user_quota 
    params += [ text_to_multipart('content_admin_mode', @content_admin_mode) ] if @content_admin_mode
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

    run_each(:createsite, args)
  end
end
