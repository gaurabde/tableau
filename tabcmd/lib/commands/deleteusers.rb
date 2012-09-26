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

class Deleteusers < MultiCommand::Command
  include Http_Util

  def initialize
    super
  end

  def doc
    <<EOM
Delete users.  The users are read from the given comma separated (csv) file.
The file is a simple list of one username per line.
EOM
  end

  def usage
    "#{name} FILENAME.CSV [options]"
  end

  # Yes, the crazy formatting of the here-is text below is intentional
  # optparse automatically indents the first but not subsequent lines
  # of the help.
  def define_options(opts,args)
    @transaction = true

    opts.on( "--[no-]complete",
             <<EOM
Require [or not] that all rows be valid
                                     for any change to succeed.
                                     Default: --complete.
EOM
      ) do |val|
      @transaction = val
    end
  end


  def delete(csv)
    begin
      csv = RelativePath.fix_path(csv)
      contents = File.open(csv, "rb").read
      encoding = CharDet.detect(contents)
      contents = Iconv.conv("UTF-8", encoding["encoding"], contents)
      request = Server.create_request("manual/upload_delete/system_users", "Post")
      basename = File.basename(csv, File.extname(csv))
      params = []
      params += [ file_to_multipart('uploaded_file', basename, "application/vnd.ms-excel", contents) ]
      params += [ text_to_multipart('reason', 'delete') ]
      params += [ text_to_multipart('format', 'xml') ]
      params += [ text_to_multipart('filename', csv) ]
      params += [ text_to_multipart('with_transaction', 'true')] if @transaction
      params += [ text_to_multipart('authenticity_token', Server.authenticity_token) ]
      request.set_multipart_form_data(params)
      logger.info "Deleting users listed in #{csv} from server..."
      response = Server.execute(request)
      logger.info Server.display_error(response, false) # Using display_error to display successful messages as well.
    rescue Iconv::Failure
      logger.error "#{csv} has invalid encoding."
    end
  end

  def run(opts,args)
    unless args.size > 0
      raise RuntimeError, "#{name} requires a users filename."
    end

    Server.login
    
    run_each(:delete, args)
  end
end
