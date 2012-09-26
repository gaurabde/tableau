# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (C) 2010    Tableau Software.
# Patents Pending.
# -----------------------------------------------------------------------

require 'uri'
require 'net/http'

class Clearannotations < MultiCommand::HiddenCommand
  include Http_Util

  def initialize
    super
  end

  def doc
    <<EOM
Remove all tags and comments from view.  Must be Administrator or have Project Leader on containing project
EOM
  end

  def usage
    "#{name} path-to-view, basically the trailing part of a single-viz url after 'http://localhost/views/'"
  end

  # Yes, the crazy formatting of the here-is text below is intentional
  # optparse automatically indents the first but not subsequent lines
  # of the help.
  def define_options(opts,args)
    @username  = nil
    @password = nil
    @view = nil
    @filename = nil

    opts.on("-v",
            "--view VIEW",
            <<EOM
friendly name
EOM
          ) do |view|
      @view = view
    end
  end

  def clear_annotations(args)
    request = Server.create_request("manual/clear_annotations/views/#{@view}", "Post")
    params = []
    params += [ text_to_multipart('format', 'xml') ]
    params += [ text_to_multipart('authenticity_token', Server.authenticity_token) ]
    request.set_multipart_form_data(params)
    logger.info "Clearing Annotations from View #{@view}"
    response = Server.execute(request)
    logger.info Server.display_error(response, false) # shows success also
  end

  def run(opts,args)
    unless @view
      raise RuntimeError, "--view argument is mandatory for #{name}"
    end

    Server.login

    clear_annotations(args)
  end
end
