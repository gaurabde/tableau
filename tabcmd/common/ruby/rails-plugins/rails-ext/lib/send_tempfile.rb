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

# accessors for mongrel-streaming monkeypatch
class ActionController::CgiResponse
  attr_accessor :cgi
end
if defined? Mongrel # anything that hasn't loaded Mongrel (like tests or db:migrate) can't use the mongrel streaming hack
  # that means this section is tested by hand only
  
  class Mongrel::CGIWrapper
    attr_accessor :response
  end
  
  module ActionController
    # Methods for sending files and streams to the browser instead of rendering.
    module Streaming
    
    protected
      # Sends a file via streaming like send_file, but it keeps a reference to the file object
      # This works better for tempfile objects (which are deleted during finalization)
      def send_tempfile(fileobj, options = {}) #:doc:
        raise MissingFile, "Cannot read file #{fileobj.path}" unless File.file?(fileobj.path) and File.readable?(fileobj.path)
  
        options[:length]   ||= File.size(fileobj.path)
        options[:filename] ||= File.basename(fileobj.path)
        send_file_headers! options
  
        @performed_render = false
        if options[:stream]
          render :status => options[:status], :text => Proc.new { |response, output|
            # this proc is called after the response "completes" in Rails
            logger.info "Streaming file #{fileobj.path}" unless logger.nil?
            chunk_size = options[:buffer_size] || 2*1024*1024
            logger.debug "(chunk size is #{chunk_size} bytes)" unless logger.nil?
  
            # make the cgiwrapper 'out' do nothing FOR THIS RESPONSE ONLY
            #   response = CgiResponse of ActionController
            #        cgi = CgiWrapper of Mongrel
            response.cgi.instance_eval do # we're within the singleton class of this object
              def out(options = "text/html", really_final=@default_really_final)
                # this method normally creates and sends headers unavoidably
                # kill this method and do it ourselves
                @out_called = true
              end
            end
  
            # write everything out to the socket now!
            response.cgi.response.instance_eval do
              # takes the place of Mongrel's HttpResponse start/finished etc
              @status = "200" #we'd better be good
              send_status(File.size(fileobj.path)) #writes status
              if not @header_sent # copy+change of send_header
                @header.out.rewind #content-length is the only thing in here
                write(@header.out.read) # don't send a Const::LINE_END here! there are headers in the "body"
                @header_sent = true
              end
              send_body # rails headers have already been dumped here
              write(Mongrel::Const::LINE_END)
              # now tack on our file, as the actual real body
              # the rest is a copy+change of Mongrel's send_file, using a larger chunk size
              File.open(fileobj.path, "rb") do |f|
                while chunk = f.read(chunk_size) and chunk.length > 0
                  begin
                    write(chunk) # writes directly to @socket
                  rescue Object => exc
                    break
                  end
                end
              end
            end
            ###response.cgi.response.send_file(fileobj.path) #uses 16k chunk size in Mongrel
          }
        else
          logger.info "Sending file #{fileobj.path}" unless logger.nil?
          File.open(fileobj.path, 'rb') { |file| render :status => options[:status], :text => file.read }
        end
      end
    end
  end
else # keep the old version (which doesn't interact with Mongrel) for tests
  module ActionController #:nodoc:
    # Methods for sending files and streams to the browser instead of rendering.
    module Streaming
    
    protected
      # Sends a file via streaming like send_file, but it keeps a reference to the file object
      # This works better for tempfile objects (which are deleted during finalization)
      def send_tempfile(fileobj, options = {}) #:doc:
        raise MissingFile, "Cannot read file #{fileobj.path}" unless File.file?(fileobj.path) and File.readable?(fileobj.path)
  
          options[:length]   ||= File.size(fileobj.path)
          options[:filename] ||= File.basename(fileobj.path)
          send_file_headers! options
  
          @performed_render = false
  
          if options[:stream]
            render :status => options[:status], :text => Proc.new { |response, output|
              logger.info "Streaming file #{fileobj.path}" unless logger.nil?
            len = options[:buffer_size] || 4096
            File.open(fileobj.path, 'rb') do |file|
              while buf = file.read(len)
                output.write(buf)
              end
            end
          }
        else
          logger.info "Sending file #{fileobj.path}" unless logger.nil?
          File.open(fileobj.path, 'rb') { |file| render :status => options[:status], :text => file.read }
        end
      end
    end
  end
end