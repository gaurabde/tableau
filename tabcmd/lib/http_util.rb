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
# lib/http_util.rb
# -----------------------------------------------------------------------
require 'net/http'
require 'uri'
require 'yaml'
require 'cgi'
require 'tempfile'

#
# Replace the request method in Net::HTTP to sniff the body type
# and set the stream if appropriate
#
# copied from http://www.missiondata.com/blog/?p=29
#

if not Net::HTTP.method_defined? :orig_request
  module Net
    class HTTP
      
      alias :orig_request :request
  
      def request(req, body = nil, &block)
        if not body.nil? and body.respond_to? :read
          req.body_stream = body
          return orig_request(req, nil, &block)
        else
          return orig_request(req, body, &block)
        end
      end
    end
    
    class HTTPResponse
      def body_stream=(f)
        @body = f
      end
      
      def is_stream?
        @body.respond_to? :read
      end
    end

    class HTTPRequest
      def reset_multipart_form_data
        return unless @multipart_params

        Http_Util::rewind_multipart @multipart_params

        multipart_headers, body_stream = MultipartParams.new(@multipart_params).get
        multipart_headers.each do |key, value|
          self[key] = value.strip
        end
        self.body_stream = body_stream

      end

      def set_multipart_form_data(params)
        @multipart_params = params
        reset_multipart_form_data
      end

      def update_multipart_form_data(params)
        if (@multipart_params)
          params.each do |p|
            @multipart_params.delete_if {|existing| existing[0] == p[0] }
            @multipart_params << p
          end
          reset_multipart_form_data
        else
          set_multipart_form_data(params)
        end
      end
    end
  end
end

module Http_Util

  public
  
  # A simple HTTP GET
  def http_get(uri)
    path = uri.path
    path += "?#{uri.query}" if uri.query
    req = Net::HTTP::Get.new(path)
    res = Net::HTTP.new(uri.host,uri.port).start do |http|
      http.read_timeout = AppConfig['wgserver.ipc.read_timeout'] unless AppConfig['wgserver.ipc.read_timeout'].nil?
      http.request(req)
    end
    case res
    when Net::HTTPSuccess
      return res.body
    else
      res.error!
    end
  end
  
  # A simple HTTP post
  def http_post(uri,params)
    req = Net::HTTP::Post.new(uri.path)
    req.form_data = params
    res = Net::HTTP.new(uri.host, uri.port).start do |http|
      http.read_timeout = AppConfig['wgserver.ipc.read_timeout'] unless AppConfig['wgserver.ipc.read_timeout'].nil?
      http.request(req)
    end
    case res
    when Net::HTTPSuccess
      return res.body
    else
      res.error!
    end
  end
  
  # An HTTP POST, with the results returned as YAML/JSON
  def http_post_json(uri,args)
    body = http_post(uri,args)
    dict = YAML.load(body)
    return dict
  end
  
  # An HTTP POST, with the results converted to JSON and
  # the "id" member returned
  def http_post_id(uri,args)
    dict = http_post_json(uri,args)
    return dict["id"]
  end
  
  # A simple HTTP delete
  def http_delete(uri)
    req = Net::HTTP::Delete.new(uri.path)
    res = Net::HTTP.new(uri.host,uri.port).start do |http|
      http.read_timeout = AppConfig['wgserver.ipc.read_timeout'] unless AppConfig['wgserver.ipc.read_timeout'].nil?
      http.request(req)
    end
    case res
    when Net::HTTPSuccess
      # OK!
    else
      res.error!
    end
  end
    
  # Methods for handling multipart/form-data posts
  
  def get_pass_through(address, return_body_stream = false)
    url = URI.parse(address)
    path = url.path + (url.query ? ('?' + url.query) : '') + (url.fragment ? ('#' + url.fragment) : '')
    resp = Net::HTTP.new(url.host,url.port).start do |http|
      http.read_timeout = AppConfig['wgserver.ipc.read_timeout'] unless AppConfig['wgserver.ipc.read_timeout'].nil?
      if return_body_stream
        http.request_get(path) do | resp |
          #return if not resp.chunked? and not resp.content_length.nil? and resp.content_length < 1024*1024*512
          resp.body_stream = spool_response resp, 'httpgetresponse'
        end
      else
        http.request_get(path)
      end
    end
    return resp
  end

  def post_pass_through(address, params, return_body_stream = false)
    # multi-part params, query and post courtesty of http://www.realityforge.org/articles/2006/03/02/upload-a-file-via-post-with-net-http
    data = ''
    header = nil
    if not params.nil? and params.size > 0
      header, data = MultipartParams.new(params).get
    end
    url = URI.parse(address)
    path = url.path + (url.query ? ('?' + url.query) : '') + (url.fragment ? ('#' + url.fragment) : '')
    resp = Net::HTTP.new(url.host,url.port).start do |http|
      http.read_timeout = AppConfig['wgserver.ipc.read_timeout'] unless AppConfig['wgserver.ipc.read_timeout'].nil?
      if return_body_stream
        http.request_post(path, data, header) do | resp |
          #return if not resp.chunked? and not resp.content_length.nil? and resp.content_length < 1024*1024*512
          resp.body_stream = spool_response resp, 'httppostresponse'
        end
      else
        http.request_post path, data, header
      end
    end
    resp
  end

  def put_pass_through(address, params, return_body_stream = false)
    # multi-part params, query and post courtesty of http://www.realityforge.org/articles/2006/03/02/upload-a-file-via-post-with-net-http
    data = ''
    header = nil
    if not params.nil? and params.size > 0
      header, data = MultipartParams.new(params).get
    end
    url = URI.parse(address)
    path = url.path + (url.query ? ('?' + url.query) : '') + (url.fragment ? ('#' + url.fragment) : '')
    resp = Net::HTTP.new(url.host,url.port).start do |http|
      http.read_timeout = AppConfig['wgserver.ipc.read_timeout'] unless AppConfig['wgserver.ipc.read_timeout'].nil?
      if return_body_stream
        http.request_put(path, data, header) do | resp |
          #return if not resp.chunked? and not resp.content_length.nil? and resp.content_length < 1024*1024*512
          resp.body_stream = spool_response resp, 'httpputresponse'
        end
      else
        http.request_put path, data, header
      end
    end
    return resp
  end

  # First seen in http://www.realityforge.org/articles/2006/03/02/upload-a-file-via-post-with-net-http
  def text_to_multipart(key,value)
    [key, value ]
  end

  # First seen in http://www.realityforge.org/articles/2006/03/02/upload-a-file-via-post-with-net-http
  def file_to_multipart(key,filename,mime_type,content)
    [ key, filename, mime_type, content ]
  end
  
  def Http_Util.rewind_multipart(params)
    params.each do | p |
      next if p.length < 4
      p[3].rewind if p[3].respond_to? :read
    end
    params
  end

  def Http_Util.generate_boundary()
    # we're shooting for a 36 digit string -- use 4 x 9 digits
    r1 = rand(1000000000)
    r2 = rand(1000000000)
    r3 = rand(1000000000)
    r4 = rand(1000000000)
    result = r1.to_s + r2.to_s + r3.to_s + r4.to_s
    return result
  end
  
  private
  
  def spool_response(resp, basename)
    file = Tempfile.new basename
    file.binmode
    resp.read_body { | segment | file.write(segment) }
    file.open.binmode #flush writes and put the file in read mode with binary behavior
    file
  end
end

class MultipartParams

  def initialize(params)
    @boundary = Http_Util::generate_boundary
    @length = 0
    streams = params.collect do |p|
      if (p.length == 4)
        # make sure we can compute the length
        if p[3].respond_to? :read
          #we aren't going to wrap it in a StringIO, make sure we can get the length
          @length = nil unless p[3].respond_to? :size or p[3].respond_to? :path
        end
        a = []
        a.push(StringIO.new(file_prefix(p[0],p[1], p[2])))
        a.push(p[3].respond_to?(:read) ? p[3] : StringIO.new(p[3].to_s))
        a.push(StringIO.new( file_suffix ))
        a
      else
        value = p[1].nil? ? '' : p[1]
        StringIO.new( text_prefix(p[0]) + value + text_suffix )
      end
    end
    streams.push StringIO.new(content_end)
    @streams = streams.flatten.reverse
    #from above, we know that if @length is not nil, then all streams are either StringIO
    #(which understands size), or it's a stream that understands size or path
    @streams.each { |s| @length += ((s.respond_to? :size) ? s.size : File.size(s.path)) } unless @length.nil?
  end

  def get
    return header, body_stream
  end

  private

  def body_stream
    StreamArrayIO.new(@streams)
  end

  def header
    ret = {}
    ret.update multipart_header
    ret.update content_length_header unless @length.nil?
    ret.update chunked_header if @length.nil?
    ret
  end
    
  def multipart_header
      { "Content-type" => "multipart/form-data; boundary=#{@boundary}\r\n" }
  end
  
  def content_length_header
    { "Content-Length" => "#{@length}" }
  end
  
  def chunked_header
    { "Transfer-Encoding" => "chunked" }
    end

  def text_prefix(key)
    "--#{@boundary}\r\n"+
    "Content-Disposition: form-data; name=\"#{CGI::escape(key)}\"\r\n" + 
         "\r\n"
  end
  
  def file_prefix(key, filename, mime_type)
    "--#{@boundary}\r\n"+
    "Content-Disposition: form-data; name=\"#{CGI::escape(key)}\"; filename=\"#{filename}\"\r\n" +
         "Content-Transfer-Encoding: binary\r\n" +
         "Content-Type: #{mime_type}\r\n" + 
         "\r\n"
  end
  
  def text_suffix
    "\r\n"
  end
  
  alias :file_suffix :text_suffix 
  
  def content_end
    "--#{@boundary}--\r\n"
  end

end

class StreamArrayIO

  def initialize(streams)
    @streams = streams
  end
      
  def read(*args)
    n = args.length == 0 ? nil : args[0]
    s = expected_eof(n)
    while s == expected_eof(n)
      s = @current_stream.read(n) unless @current_stream.nil?
      break if s == expected_eof(n) and not next_stream
    end
    s
  end
  
  def next_stream
    return false if @streams.empty?
    @current_stream = @streams.pop
    true
  end
  
  def expected_eof(n)
    n.nil? ? "" : nil
  end
end 

