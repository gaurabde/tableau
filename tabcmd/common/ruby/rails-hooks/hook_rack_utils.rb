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
#
# Multiple monkey patches to Rack::Utils
#
# 1) fix cascading if to be a bit pickier about types
#   @see  https://github.com/brendan/rack/commit/8f7fcf0fdd9fd99aa529159d05c63dc2b0bfe08a
#   until ruby 1.9 (or a back-port of this bug to the 1.8 codeline
#
# 2) Rails2 put all parms from multipart posts into tempfiles, and we patched that to use strings below a certain size
#    Ironically, Rails3 puts everything into strings, so we put things above threshhold into tempfiles
#
# 3) Rails3 much pickier about boundary separator syntax, yet our own components post incompatible forms, so we must
#     fix the form parsing to handle variable boundary lengths
# -----------------------------------------------------------------------


module Rack
  module Utils
    def rfc2822(time)
      wday = Time::RFC2822_DAY_NAME[time.wday]
      mon = Time::RFC2822_MONTH_NAME[time.mon - 1]
      #time.strftime("#{wday}, %d-#{mon}-%Y %T GMT") but %T is broken in 1.8.7 and windows
      time.strftime("#{wday}, %d-#{mon}-%Y %H:%M:%S GMT")
    end
    module_function :rfc2822



    module Multipart
      def self.parse_multipart(env)
        unless env['CONTENT_TYPE'] =~
            %r|\Amultipart/.*boundary=\"?([^\";,]+)\"?|n
          nil
        else
          boundary = "--#{$1}"

          params = {}
          buf = ""
          content_length = env['CONTENT_LENGTH'].to_i
          input = env['rack.input']
          input.rewind

          boundary_size = Utils.bytesize(boundary) + EOL.size
          bufsize = 16384

          content_length -= boundary_size

          read_buffer = ''

          status = input.read(boundary_size, read_buffer)
          raise EOFError, "bad content body" unless status == boundary + EOL

          ## Tableau dlion 17 May 2011
          ## First group must leave a backreference !!
          ## We need to know whether the boundary has the preceding EOL, so that we advance the correct amount
          ## since some pieces of desktop's multipart post do not have the EOL at start of boundary
          ## Backrefernces to $1 now refer to $2
          #  rx = /(?:#{EOL})?#{Regexp.quote boundary}(#{EOL}|--)/n
          rx = /(#{EOL})?#{Regexp.quote boundary}(#{EOL}|--)/n

          loop {
            head = nil
            body = ''
            filename = content_type = name = nil

            until head && buf =~ rx
              if !head && i = buf.index(EOL+EOL)
                head = buf.slice!(0, i+2) # First \r\n
                buf.slice!(0, 2)          # Second \r\n

                token = /[^\s()<>,;:\\"\/\[\]?=]+/
                condisp = /Content-Disposition:\s*#{token}\s*/i
                dispparm = /;\s*(#{token})=("(?:\\"|[^"])*"|#{token})*/

                rfc2183 = /^#{condisp}(#{dispparm})+$/i
                broken_quoted = /^#{condisp}.*;\sfilename="(.*?)"(?:\s*$|\s*;\s*#{token}=)/i
                broken_unquoted = /^#{condisp}.*;\sfilename=(#{token})/i

                if head =~ rfc2183
                  filename = Hash[head.scan(dispparm)]['filename']
                  filename = $2 if filename and filename =~ /^"(.*)"$/
                elsif head =~ broken_quoted
                  filename = $2
                elsif head =~ broken_unquoted
                  filename = $2
                end

                if filename && filename !~ /\\[^\\"]/
                  filename = Utils.unescape(filename).gsub(/\\(.)/, '\1')
                end

                content_type = head[/Content-Type: (.*)#{EOL}/ni, 1]
                name = head[/Content-Disposition:.*\s+name="?([^\";]*)"?/ni, 1] || head[/Content-ID:\s*([^#{EOL}]*)/ni, 1]

                if filename
                  body = Tempfile.new("RackMultipart")
                  body.binmode  if body.respond_to?(:binmode)
                end

                next
              end

              ## tableau dlion 17 may 2011
              ## move anything bigger than one buffer-full into a tempfile
              if body.size >= bufsize && body.is_a?(String)
                tmpfile = Tempfile.new('RackMultipartLarge')
                tmpfile.binmode()
                tmpfile.write(body)
                body = tmpfile
              end

              # Save the read body part.
              if head && (boundary_size+4 < buf.size)
                body << buf.slice!(0, buf.size - (boundary_size+4))
              end

              c = input.read(bufsize < content_length || content_length < 0 ? bufsize : content_length, read_buffer)
              raise EOFError, "bad content body" if c.nil? || c.empty?
              buf << c
              content_length -= c.size
            end

            # Save the rest.
            if i = buf.index(rx)
              ## boundary found.  Record whether it has preceding EOL
              matches = rx.match(buf)
              leading_eol = false
              if matches # something is very wrong if matches is nil
                leading_eol = !matches[1].nil?
              end
              body << buf.slice!(0, i)
              buf.slice!(0, boundary_size + (leading_eol ? EOL.size : 0))

              content_length = -1  if $2 == "--"
            end

            if filename == ""
              # filename is blank which means no file has been selected
              data = nil
            elsif filename
              body.rewind

              # Take the basename of the upload's original filename.
              # This handles the full Windows paths given by Internet Explorer
              # (and perhaps other broken user agents) without affecting
              # those which give the lone filename.
              filename = filename.split(/[\/\\]/).last

              data = {:filename => filename, :type => content_type,
                :name => name, :tempfile => body, :head => head}
              ##            elsif !filename && content_type
              ## @see  https://github.com/brendan/rack/commit/8f7fcf0fdd9fd99aa529159d05c63dc2b0bfe08a
            elsif !filename && content_type && body.is_a?(Tempfile)
              body.rewind

              # Generic multipart cases, not coming from a form
              data = {:type => content_type,
                :name => name, :tempfile => body, :head => head}
            else
              data = body
            end

            Utils.normalize_params(params, name, data) unless data.nil?
            # break if we're at the end of a buffer, but not if it is the end of a field
            break if (buf.empty? && $2 != EOL) || content_length == -1
          }

          input.rewind

          params
        end
      end

    end

  end
end

