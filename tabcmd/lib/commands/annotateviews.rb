# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (C) 2010    Tableau Software.
# Patents Pending.
# -----------------------------------------------------------------------

require 'uri'
require 'net/http'

class Annotateviews < MultiCommand::HiddenCommand
  include Http_Util

  def initialize
    super
  end

  def doc
    <<EOM
Annotate named view(s) with comments and tag.  Always additive, does not clear any comments or tags.
EOM
  end

  def usage
    "#{name} --file <path-to-annotation-file>"
  end

  # Yes, the crazy formatting of the here-is text below is intentional
  # optparse automatically indents the first but not subsequent lines
  # of the help.
  def define_options(opts,args)
    @username  = nil
    @password = nil
    @view = nil
    @filename = nil

    opts.on("--file FILENAME.xml",
<<EOM
File containing xml description of the
                                     views and annotations.

 --Sample File:-----------------------------------------------
 <?xml version='1.0' encoding='utf-8' ?>

 <view name="samples/dashboard">
   <tag>dashboard_one</tag>
   <tag>dashboard_two</tag>
   <tag>shared_one</tag>
   <comment>this dashboard comment for rent</comment>
   <comment>inquire within</comment>
 </view>

 <view name="samples/bars">
   <tag>bars_one</tag>
   <tag>bars_two</tag>
   <tag>shared_one</tag>
   <comment>only the bars view gets this comment</comment>
 </view>
 ------------------------------------------------------------
EOM
          ) do |filename|
      @filename = RelativePath.fix_path(filename)
    end

  end

  def annotate_view(args, file)
    request = Server.create_request("manual/annotate/views", "Post")
    basename = File.basename(@filename, File.extname(@filename))
    params = []
    params += [ file_to_multipart('uploaded_file', basename, "application/vnd.ms-excel", file) ]
    params += [ text_to_multipart('format', 'xml') ]
    params += [ text_to_multipart('filename', @filename) ]
    params += [ text_to_multipart('authenticity_token', Server.authenticity_token) ]
    request.set_multipart_form_data(params)
    response = Server.execute(request)
    logger.info Server.display_error(response, false) # shows success also
  end

  def run(opts,args)
    unless @filename
      raise RuntimeError, "--file argument is mandatory for #{name}"
    end

    Server.login

    File.open(@filename, "rb") do |file|
      annotate_view(args, file)
    end
  end
end
