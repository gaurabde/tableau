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

class Syncgroup < MultiCommand::Command
  include Http_Util

  def initialize
    super
  end

  def doc
    <<EOM
Sync the server with an Active Directory group.
EOM
  end

  # Yes, the crazy formatting of the here-is text below is intentional
  # optparse automatically indents the first but not subsequent lines
  # of the help.
  def define_options(opts,args)
    @license = nil
    @admin = nil
    @publisher = nil
    @transaction = true

    opts.on( "--license LEVEL",
             <<EOM
Sets the license level for all users
                                     in the group.  LEVEL may be
                                     Interactor, Viewer, or Unlicensed.
EOM
      ) do |val|
        licenselevels = ['interactor', 'viewer', 'unlicensed']
        if licenselevels.include?(val.downcase)
           @license = val
        else
           raise RuntimeError, "Only one license level (Interactor, Viewer, or Unlicensed) can be specified."
        end
        @license = val
      end

    opts.on( "--administrator TYPE",
             <<EOM
Assigns or removes the Administrator right for all users 
                                     in the group. The Administrator user type may be 
                                     System, Content, or None.  
                                     Default: None for new users, unchanged for existing users.
EOM
      ) do |val|
        admintypes = ['system', 'content', 'none']
        if admintypes.include?(val.downcase)
           @admin = val
        else
           raise RuntimeError, "Only one Administrator user type (System, Content, or None) can be specified."
        end
    end

    opts.on( "--[no-]publisher",
             <<EOM
Assigns [or removes] the Publish right
                                     for all users in the group.
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
    opts.on("--silent-progress",
            "do not display progress messages for asynchronous job") do |val|
      Server.silent = true
    end
  end

  def usage
    "#{name} GROUPNAME [options]"
  end

  def syncgroup(name)
    logger.info "Synchronizing server with Active Directory group #{name}..."
    request = Server.create_request("manual/group_chosen/groups", "Post")
    params = []
    params += [ text_to_multipart('group', name) ]
    params += [ text_to_multipart('format', 'xml') ]
    params += [ text_to_multipart('level', @license) ] unless @license.nil?
    params += [ text_to_multipart('admin', @admin) ] unless @admin.nil?
    params += [ text_to_multipart('publisher', @publisher ? 'true' : 'false')] unless @publisher.nil?
    params += [ text_to_multipart('with_transaction', 'true')] if @transaction
    params += [ text_to_multipart('authenticity_token', Server.authenticity_token) ]
    request.set_multipart_form_data(params)
    jobResponse = ""
    Server.with_silence do
        response = Server.execute(request)
        jobResponse = Server.monitor_job(response)
    end
    logger.info jobResponse unless Server.silent
  end

  def run(opts,args)
    unless args.size > 0
      raise RuntimeError, "#{name} requires a group name."
    end

    Server.login

    run_each(:syncgroup, args)
  end
end
