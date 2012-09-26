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
require 'openssl'

class GetUrl < MultiCommand::Command
  def initialize
    super
  end

  def name
    "get"
  end

  def doc
    <<EOM
Get a file from the server.  The file will be named after the last component
of the path.
EOM
  end

  def usage
    "#{name} url [options]"
  end

  def define_options(opts,args)
    @filename = nil

    opts.on("-f",
            "--filename NAME",
            "Name to save the file as."
          ) do |filename|
      @filename = RelativePath.fix_path(filename)
    end
  end

    # The function reuest the server resource designated by relative and then store
    # the body of the response into a file. The response itself is returned.
  def get(relative)
    logger.info "Requesting #{relative} from server..."
    relative.gsub!(%r<^/>,'')
    request = Server.create_request(relative)
    # Passing filename and relative as arguments so it can figure out where to store
    response = Server.execute(request,{:filename => @filename, :relative => relative})
  end

  def run(opts,args)
    unless args.size > 0
      raise RuntimeError, "#{name} requires a url."
    end

    Server.login
    
    run_each(:get, args)
  end
end
