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

class Delete < MultiCommand::Command
  include Http_Util

  def initialize
    super
  end

  def doc
    <<EOM
Delete a workbook or datasource from the server.
EOM
  end

  def define_options(opts,args)
    @project = nil
    @workbook_name = nil
    @datasource_name = nil

    opts.on("-r",
            "--project PROJECT",
            "Default: default"
          ) do |project|
      @project = project
    end
    opts.on('--workbook WORKBOOK_NAME',
            <<EOM
The name of the workbook to delete.
EOM
          ) do |workbook|
      @workbook_name = workbook
    end
    opts.on('--datasource DATASOURCE_NAME',
            <<EOM
The name of the datasource to delete.
EOM
          ) do |datasource|
      @datasource_name = datasource
    end
  end

  def usage
    "#{name} WORKBOOK [options]"
  end

  def delete(workbook)
    params = []
    @project = @project || "Default"
    if workbook || @workbook_name
      request_path = "manual/delete_by_name/workbooks"
      name = workbook || @workbook_name
    elsif @datasource_name
      request_path = "manual/delete_by_name/datasources"
      name = @datasource_name
    else
      raise RuntimeError, "#{name} requires a workbook or datasource name."
    end

    logger.info "Deleting #{name} from project #{@project} on server..."
    
    params += [ text_to_multipart('name', name) ]
    params += [ text_to_multipart('format', 'xml') ]
    params += [ text_to_multipart('project', @project) ]
    params += [ text_to_multipart('authenticity_token', Server.authenticity_token) ]
    request = Server.create_request(request_path, "Post")
    request.set_multipart_form_data(params)
    Server.execute(request)
  end

  def run(opts,args)
    Server.login

    run_each(:delete, args.length == 0 ? [nil] : args)
  end
end
