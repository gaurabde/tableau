# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (C) 2008-9    Tableau Software.
# Patents Pending.
# -----------------------------------------------------------------------

require 'uri'
require 'net/http'
require 'file_util'

class Addusers < MultiCommand::Command
  include Http_Util

  def initialize
    super
  end

  def doc
    <<EOM
Add users to a group.
EOM
  end

  def usage
    "#{name} GROUPNAME [options]"
  end

  # Yes, the crazy formatting of the here-is text below is intentional
  # optparse automatically indents the first but not subsequent lines
  # of the help.
  def define_options(opts,args)
    @filename    = nil
    @transaction = true

    opts.on("--users FILENAME.CSV",
            <<EOM
File containing a list of users, one
                                     per line, to add to the group.
EOM
          ) do |filename|
      @filename = RelativePath.fix_path(filename)
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

  def addusers(group, file)
    request = Server.create_request("manual/upload_add_or_remove_users/groups", "Post")
    basename = File.basename(@filename, File.extname(@filename))
    params = []
    params += [ file_to_multipart('uploaded_file', basename, "application/vnd.ms-excel", file) ]
    params += [ text_to_multipart('format', 'xml') ]
    params += [ text_to_multipart('filename', @filename) ]
    params += [ text_to_multipart('with_transaction', 'true')] if @transaction
    params += [ text_to_multipart('group', group) ]
    params += [ text_to_multipart('authenticity_token', Server.authenticity_token) ]
    request.set_multipart_form_data(params)
    logger.info "Adding users listed in #{@filename} to group #{group}..."
    response = Server.execute(request)
    logger.info Server.display_error(response, false) # Using display_error to display successful messages as well.
  end

  def run(opts,args)
    unless args.size > 0
      raise RuntimeError, "#{name} requires a group name."
    end
    unless @filename
      raise RuntimeError, "--users argument is mandatory for #{name}"
    end
    Server.login
    contents = FileUtil::get_file_ensure_utf8(@filename)
    run_each(:addusers, args, contents)
  end
end
