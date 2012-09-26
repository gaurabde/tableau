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
require 'http_util'
require 'openssl'

class Publish < MultiCommand::Command
  include Http_Util

  def initialize
    super
  end

  def doc
    <<EOM
Publish a workbook/datasource to the server.
EOM
  end

  # Yes, the crazy formatting of the here-is text below is intentional
  # optparse automatically indents the first but not subsequent lines
  # of the help.
  def define_options(opts,args)
    @db_password = nil
    @db_username = nil
    @name = nil
    @overwrite = false
    @project = "Default"
    @save_db_password = false
    @thumb_user = nil
    @thumb_group = nil
    @keychain_key = nil
    @keychain = nil

    opts.on("-n",
            "--name NAME",
            <<EOM
Workbook/datasource name on the server. If
                                     omitted, the workbook/datasource will 
                                     be named after the filename, without the
                                     twb(x) or tds(x) extension.
EOM

          ) do |name|
      @name = name
    end
    opts.on("-o",
            "--overwrite",
            "Overwrite the existing workbook/datasource, if any."
          ) do
      @overwrite = true
    end
    opts.on("-r",
            "--project NAME",
            "Project to publish the workbook/datasource to."
          ) do |name|
      @project = name
    end
    opts.on("--db-username NAME",
            "Database username for all data sources."
           ) do |name|
      @db_username = name
    end
    opts.on("--db-password PASSWORD",
            "Database password for all data sources."
           ) do |pw|
      @db_password = pw
    end
    opts.on("--save-db-password",
            <<EOM
Store the database password on server.
EOM
            ) do
      @save_db_password = true
    end
    opts.on("--thumbnail-username USERNAME",
            <<EOM
If the workbook contains any user
                                     filters, impersonate this user while
                                     computing thumbnails.
EOM
           ) do |name|
      @thumb_user = name
    end
    opts.on("--thumbnail-group GROUPNAME",
            <<EOM
If the workbook contains any user
                                     filters, impersonate this group while
                                     computing thumbnails.
EOM
           ) do |name|
      @thumb_group = name
    end
    opts.on("--tabbed",
            "publish with tabbed views enabled"
          ) do
      @tabbed = true
    end
  end

  def usage
    "#{name} <a workbook | datasource> [options]"
  end

  def make_keychain
    # Fetch the public key always, even if we don't really have to, as it
    # verifies that the server is functioning before we let publish run with
    # a 10-minute timeout.
    key = Server.request_public_key('manual/pubkey/workbooks.xml', 'keyinfo', :auto_login => true)

    return unless (@db_username || @db_password)

    keychain = "<keychain version='6.3'>\n"

    keychain += "<connection> <value "
    keychain += "username='#{@db_username}' " if @db_username
    keychain += "password='#{@db_password}' " if @db_password
    keychain += "/> </connection>\n </keychain>\n"
    @keychain_key, @keychain = Server.symmetric_encrypt(keychain, key)
  end

  def display_url(xml, file_type)
    doc = REXML::Document.new(xml)
    wb_tag = doc.elements[1, file_type.to_s]
    wb_tag || return
    url_tag = wb_tag.elements[1, 'repository-url']
    url_tag || return
    url = Server.compose_url("#{file_type.to_s}s/#{url_tag.text}")
    logger.info "File successfully published to the Tableau Server, at the following location:"
    logger.info url
    return url
  end

  def publish(fileArg)
    fileArg = RelativePath.fix_path(fileArg)
    if @thumb_user && @thumb_group
      raise RuntimeError, "Use only one of --thumbnail-username or --thumbnail-group"
    end
    
    file_ext = File.extname(fileArg);
    
    case file_ext.downcase
      when ".tds", ".tdsx"
        file_type = :datasource
      when ".twb", ".twbx"
        file_type = :workbook
      else 
        raise RuntimeError, "Unknown file type, expected *.tds, *.twb, or *.twbx: " + fileArg
    end
    
    File.open(fileArg, "rb") do |file|
      name = @name || File.basename(fileArg, file_ext)
      logger.info "Publishing #{fileArg} to server.  This could take several minutes..."
      request = Server.create_request("manual/create/#{file_type.to_s}s.xml", 'Post')
      params = []
      # Need to take project name argument into account
      params += [ text_to_multipart('full_keychain_key', @keychain_key) ] if @keychain_key
      params += [ file_to_multipart('full_keychain', 'foo', 'application/octet', @keychain) ] if @keychain
      params += [ text_to_multipart('project_name', @project) ]
      params += [ text_to_multipart('no_overwrite', 'true') ] unless @overwrite
      params += [ text_to_multipart('tabs_allowed', 'true') ] if @tabbed
      params += [ text_to_multipart('discard_keychain', 'true')] unless @save_db_password
      params += [ text_to_multipart('name', name) ]
      params += [ text_to_multipart('compute_metadata', 'true') ]
      params += [ text_to_multipart('impersonate_username', @thumb_user)] if @thumb_user
      params += [ text_to_multipart('impersonate_groupname', @thumb_group)] if @thumb_group
      params += [ file_to_multipart(file_type == :workbook ? 'twb' : 'tds', 'file', 'application/octet', file) ]
      params += [ text_to_multipart('authenticity_token', Server.authenticity_token) ]
      params += [ text_to_multipart('http_timeout', Server.timeout.to_s) ] unless Server.timeout.nil?
      request.set_multipart_form_data(params)
      timeout = File.size(fileArg) / (1024*1024)
      timeout = 600 if timeout < 600
      response = Server.execute(request, { :signal_success => false, :read_timeout => timeout})
      unless display_url(response.body, file_type)
        raise RuntimeError, "Unexpected response from server #{response.body}"
      end
    end
  end

  def run(opts,args)
    unless args.length > 0
      raise RuntimeError, "#{name} requires a workbook or datasource file."
    end
    if (args.length > 1 && @name)
      raise RuntimeError, "--name option is invalid when publishing multiple workbooks."
    end
    
    Server.login

    make_keychain
    run_each(:publish, args)
  end
end
