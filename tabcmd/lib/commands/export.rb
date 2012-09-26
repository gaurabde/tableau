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

class Export < MultiCommand::Command
  def initialize
    super
  end

  def name
    "export"
  end

  def doc
    <<EOM
Export the data or image of a view from the server.  The file will be named after the view name.
EOM
  end

  def usage
    "#{name} WORKBOOK/VIEW [options]"
  end

  def define_options(opts,args)
    @filename = nil
    @export_format = "csv" # default export format
    @ext = ".csv" # default filename extension
    @got_format = false;
    @pagesize = "letter"
    @pagelayout = nil
    @select_all = false

    opts.on("-f",
            "--filename NAME",
            "Name to save the file as."
          ) do |filename|
      @filename = filename
    end
    opts.on("--csv",
            "export data in csv format (default)"
          ) do |csv|
      if !@got_format
          @got_format = true
          @export_format = "csv"
          @ext = ".csv"
      else
          raise RuntimeError, "only one of the format types (csv, pdf, fullpdf and png) can be specified."
      end
    end
    opts.on("--pdf",
            "export view in PDF format"
          ) do |pdf|
      if !@got_format
          @got_format = true
          @export_format = "pdf"
          @ext = ".pdf"
      else
          raise RuntimeError, "only one of the format types (csv, pdf, fullpdf and png) can be specified."
      end
    end
    opts.on("--png",
            "export view in PNG format"
          ) do |png|
      if !@got_format
          @got_format = true
          @export_format = "png"
          @ext = ".png"
      else
          raise RuntimeError, "only one of the format types (csv, pdf, fullpdf and png) can be specified."
      end
    end
    opts.on("--fullpdf",
            "export visible views in PDF format (if workbook was published with tabs)"
          ) do |fullpdf|
      if !@got_format
          @got_format = true
          @export_format = "pdf"
          @ext = ".pdf"
          @select_all = true
      else
          raise RuntimeError, "only one of the format types (csv, pdf, fullpdf and png) can be specified."
      end
    end
    # B48406 - exposing settings for page size/orientation (defaults are letter and landscape)
    opts.on( "--pagesize PAGESIZE",
             <<EOM
Sets the page size of the exported PDF.  PAGESIZE may be
                                     unspecified, letter, legal, note, folio, tabloid, ledger, statement,
                                     executive, a3, a4, a5, b4, b5 or quarto (default: letter).
EOM
      ) do |val|
          pagesizeoptions = ['unspecified', 'letter', 'legal', 'note', 'folio', 'tabloid', 'ledger', 'statement', 'executive', 'a3', 'a4', 'a5', 'b4', 'b5','quarto']
          if pagesizeoptions.include?(val)
             @pagesize = val
          else
             raise RuntimeError, "Only one of the page sizes (unspecified, letter, legal, note, folio, tabloid, ledger, statement,executive, a3, a4, a5, b4, b5 or quarto) can be specified."
          end
      end
    opts.on( "--pagelayout PAGELAYOUT",
             <<EOM
Sets the page orientation of the exported PDF.
                                     PAGELAYOUT may be portrait or landscape (If this is unspecified,
                                     then the setting in Tableau Desktop will be used).
EOM
      ) do |val|
        pagelayouts = ['portrait', 'landscape']
        if pagelayouts.include?(val)
           @pagelayout = val
        else
           raise RuntimeError, "Only one of the page layouts (portrait or landscape) can be specified."
        end
    end
  end

  def export(workbookView)
    unless workbookView.count("/") >= 1
      raise RuntimeError, "#{name} requires a WORKBOOK/VIEW parameter, and there must be at least 1 forward slash (/) in this parameter." 
    end

    workbook, view, *rest = workbookView.split('/')
    filename = @filename
    response = nil

    unless workbook && view
      raise RuntimeError, "#{name} requires a WORKBOOK/VIEW."
    end

    logger.info "Requesting #{workbookView} from server..."

    if @select_all
      filename ||= workbook
    else
      filename ||= view
    end

    if @export_format == "pdf"
      export_response = nil
      # open a server session on the view, send pdf-export command
      Server.with_silence do
        Server.request_bootstrap(workbookView)
        # B48406 - API for the user to supply non-default options is for page size and page layout.
        # TODO - page scaling and 'sheets to export' options.

        options_response = Server.execute_command("tabsrv", "pdf-export-options")

        # B48406 - setting the page size and page orientation before sending the POST request to server.
        export_options = options_response["pdfExport"]
        export_options["pageSizeOption"] = @pagesize if @pagesize
        export_options["pageOrientationOption"] = @pagelayout if @pagelayout
        # select all published sheets
        export_options["sheetOptions"].each do |s|
          should_select = @select_all || (s["sheet"] == export_options["currentSheet"])
          s["isSelected"] = s["isPublished"] && should_select
          s["pageSizeOption"] = @pagesize if @pagesize
          s["pageOrientationOption"] = @pagelayout if @pagelayout
        end

        export_response = Server.execute_command("tabsrv", "pdf-export-server", options_response)
      end

      tempfileKey = export_response['pdfResult']['tempfileKey']
      response = Server.request_tempfile(tempfileKey)
    else
      # B47702 - omit the preceeding '/' from the request URL
      # B48444 - detecting if view URL contains query string, then constructing the get URL accordingly.
      s = workbookView.include?('?') ? '&' : '?'
      response = Server.execute_request(url = "views/" + workbookView + s + "format=" + @export_format)
	  
      # if the response is an attachment, then use that as the filename
      # (unless the user supplied a filename)
      if !@filename && response.key?('content-disposition')
        disposition = response['content-disposition']

        if disposition =~ /^attachment; filename="(.+)"$/
          filename = $1
          # the server now returns the title of the wb as the filename, instead of
          # the repo_id. Must remove all the illegal Windows filename characters
          newfilename = filename.gsub(/[":<>*?|\/\\]/, '_')
          if newfilename == filename
            logger.info "Found attachment: #{filename}."
          else
            logger.info "Found attachment: #{filename} (remapped to #{newfilename})."
            filename = newfilename
          end
        end
      end
    end

    if (filename =~ /#{@ext}$/i) == nil
      filename += @ext
    end

    File.open(RelativePath.fix_path(filename), 'wb') do |file|
      file.write(response.body)
      logger.info "Saved #{workbookView} to #{filename}."
    end
  end

  def run(opts,args)
    unless args.size > 0
      raise RuntimeError, "#{name} requires a WORKBOOK/VIEW."
    end

    Server.login

    run_each(:export, args)
  end
end
