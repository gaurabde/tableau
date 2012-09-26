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

class Refreshextracts < MultiCommand::Command
  include Http_Util

  def initialize
    super
  end

  def doc
    <<EOM
Refresh the extracts of a workbook or datasource on the server.
EOM
  end

  def define_options(opts,args)
    @synchronous = false
    @incremental = false
    @project_name = nil
    @workbook_name = nil
    @workbook_url = nil

    opts.on('--incremental', 
            <<EOM
Do an incremental refresh.
EOM
          ) do
      @incremental = true
    end
    opts.on('--synchronous', 
            <<EOM
Run the refresh immediately in the
                                     foreground.
EOM
          ) do
      @synchronous = true
    end
    opts.on('--workbook WORKBOOK_NAME',
            <<EOM
The name of the workbook to refresh.
EOM
          ) do |workbook|
      @workbook_name = workbook
    end
    opts.on('--datasource DATASOURCE_NAME',
            <<EOM
The name of the datasource to refresh.
EOM
          ) do |datasource|
      @datasource_name = datasource
    end
    opts.on('--project PROJECT_NAME',
            <<EOM
The name of the project containing the 
                                     workbook/datasource.  Only necessary if 
                                     --workbook or --datasource is specified. 
                                     Default: "Default"
EOM
          ) do |project|
      @project_name = project
    end
    opts.on('--url WORKBOOK_URL',
            <<EOM
The the canonical name that appears in URL
                                     path names for the workbook or the 
                                     workbook's views
EOM
          ) do |url|
      @workbook_url = url
    end
    
  end

  def usage
    "#{name} [WORKBOOK_URL] [options]" 
  end

  def refreshextracts(workbook)
    request_path = "manual/refresh_extracts/workbooks"
    obj_name = "workbook"
    params = []
    if workbook
        params += [ text_to_multipart('url', workbook) ]
        obj_identifier = workbook
    elsif @workbook_name
        params += [ text_to_multipart('name', @workbook_name) ]
        params += [ text_to_multipart('project', @project_name || "Default") ]
        obj_identifier = (@project_name || "Default") + "/" + @workbook_name
    elsif @datasource_name
        params += [ text_to_multipart('name', @datasource_name) ]
        params += [ text_to_multipart('project', @project_name || "Default") ]
        obj_identifier = (@project_name || "Default") + "/" + @datasource_name
        request_path = "manual/refresh_extracts/datasources"
        obj_name = "datasource"
    end
    params += [ text_to_multipart('format', 'xml') ]
    params += [ text_to_multipart('synchronous', 'true') ] if @synchronous
    params += [ text_to_multipart('incremental', 'true') ] if @incremental
    params += [ text_to_multipart('authenticity_token', Server.authenticity_token) ]
    
    request = Server.create_request(request_path, "Post")
    request.set_multipart_form_data(params)
    operation = @incremental ? 'incremented' : 'refreshed'
    if @synchronous
      logger.info "Extracts for #{obj_name} '#{obj_identifier}' to be #{operation} synchronously now..."
    else
      logger.info "Scheduling extracts for #{obj_name} '#{obj_identifier}' to be #{operation} now..."
    end
    response = Server.execute(request)
    logger.info Server.display_error(response, false)
  end

  def run(opts,args)
    unless args.size > 0 || @workbook_name || @workbook_url || @datasource_name
      raise RuntimeError, "#{name} requires a workbook URL, workbook name, or datasource name."
    end
    
    Server.login

    run_each(:refreshextracts, Array[args[0] || @workbook_url])
  end
end
