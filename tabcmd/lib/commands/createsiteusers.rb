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
require 'file_util'

class Createsiteusers < MultiCommand::Command
  include Http_Util

  def initialize
    super
  end

  def doc
    <<EOM
Create users on the current site.  The users are read from the given comma separated values (csv)
file. The file may have the columns in the order shown below.

1. Username
2. Password        (Ignored if using Active Directory)
3. Friendly Name   (Ignored if using Active Directory)
4. License Level (Interactor, Viewer, or Unlicensed)
5. Administrator (content/none)
6. Publisher (yes/true/1 or no/false/0)
7. Email (only for Tableau Public)
The file can have fewer columns. For example it can be a simple list with one
username per line. Quotes may be used if a value contains commas.

Tabcmd waits for the createsiteusers task to complete.  You may choose not to wait for the task
to complete on the Server and instead return immediately by passing the --nowait flag.

System administrators cannot be created or demoted using this command. Use 'createusers' instead.
EOM
  end

  def usage
    "#{name} FILENAME.CSV [options]"
  end

  def define_options(opts, args)
    @license = nil
    @publisher = nil
    @transaction = true

    opts.on("--nowait",
      "do not wait for asynchronous job to complete") do |monitor|
      Server.monitor = false
    end

    opts.on("--silent-progress",
      "do not display progress messages for asynchronous job") do |monitor|
      Server.silent = true
    end

    opts.on( "--license LEVEL",
      <<EOM
Sets the default license level for all
                                     users.  This may be overridden by the
                                     value in the CSV file. LEVEL may be
                                     Interactor, Viewer, or Unlicensed.
EOM
    ) do |val|
      @license = val
    end
    
    opts.on( "--admin-type TYPE", ["content", "none"],
      <<EOM
Assigns [or removes] the content admin right
                                     for all users in the CSV file. This
                                     setting may be overridden by the values
                                     on individual rows in the CSV file.
                                     TYPE may be: content, or none
                                     Default: none for new users
                                              unchanged for existing users.
EOM
    ) do |val|
      @admin_type = val
    end
    opts.on( "--[no-]publisher",
      <<EOM
Assigns [or removes] the Publish right
                                     for all users in the CSV file. This
                                     setting may be overridden by the values
                                     on individual rows in the CSV file.
                                     Default: no for new users
                                              unchanged for existing users.
EOM
    ) do |val|
      @publisher = val
    end
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

  def import_to_site(csv)
    real_admin = "none"
    real_admin = @admin_type unless @admin_type.nil?
    contents = FileUtil::get_file_ensure_utf8(csv)
    request = Server.create_request("manual/upload_action/users", "Post")
    basename = File.basename(csv, File.extname(csv))
    params = []
    params += [ file_to_multipart('uploaded_file', basename, "application/vnd.ms-excel", contents) ]
    params += [ text_to_multipart('reason', 'import') ]
    params += [ text_to_multipart('format', 'xml') ]
    params += [ text_to_multipart('filename', csv) ]
    params += [ text_to_multipart('level', @license) ] unless @license.nil?
    params += [ text_to_multipart('admin', real_admin) ]
    params += [ text_to_multipart('publisher', @publisher ? 'true' : 'false')] unless @publisher.nil?
    params += [ text_to_multipart('with_transaction', 'true')] if @transaction
    params += [ text_to_multipart('authenticity_token', Server.authenticity_token) ]
    request.set_multipart_form_data(params)
    logger.info "Adding users listed in #{csv} to current site..."
    response = Server.execute(request)
    if Server.monitor
      ending_status = Server.monitor_job(response) if Server.monitor
      logger.info(ending_status) # Using display_error to display successful messages as well.
      puts(ending_status) unless Server.silent # Using display_error to display successful messages as well.
    else
      logger.info Server.display_error(response, false) # Using display_error to display successful messages as well.
    end
  end

  def run(opts,args)
    unless args.size > 0
      raise RuntimeError, "#{name} requires a users csv file."
    end

    Server.login

    run_each(:import_to_site, args)
  end
end
