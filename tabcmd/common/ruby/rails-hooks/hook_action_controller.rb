module ActionController #:nodoc:
  class LogSubscriber < ActiveSupport::LogSubscriber
    def start_processing(event)
      payload = event.payload
      params  = payload[:params].except(*INTERNAL_PARAMS)
      info "  Processing by #{payload[:controller]}##{payload[:action]} as " +
        " #{payload[:formats].first.to_s.upcase}" +
        " _origin=#{utc_request_origin(payload)}"
      info "  Session ID: #{payload[:session_id]}"
      info "  Parameters: #{params.inspect}" unless params.empty?
    end


    def timestring
      n = Time.now
      us = n.usec.to_s[0..2]
      return %Q[#{n.strftime "%Y-%m-%d %H:%M:%S"},#{us}]
    end

    # Replace ActionController::Base method so that logging shows the actual remote ip address
    # not the default Rails request.remote_ip address.
    # this variant uses the default time format, could be important to some 3rd party log parsing tool.  See below for our alternative
    def request_origin
      # this *needs* to be cached!
      # otherwise you'd get different results if calling it more than once
      @request_origin ||= "#{@_request.get_remote_ip} at #{Time.now.to_s(:db)}"
    end

    # Variant to use our own local time format
    # which currently has local, millis
    # someday might have utc, millis
    def utc_request_origin(payload)
      @request_origin ||= "#{payload[:remote_ip]} at #{timestring}"
    end

    protected
    # Sets a HTTP 1.1 Cache-Control header of "no-cache" so no caching should occur by the browser or
    # intermediate caches (like caching proxy servers).
    def expires_now #:doc:
      response.headers["Cache-Control"] = "no-cache, no-store" ## see case 23024
    end

  end

  ## Because apache does all our crazy routing, we don't want any scriptnames inserted by Rails
  module UrlFor
    def url_options
      super.reverse_merge(
        :host => request.host_with_port,
        :protocol => request.protocol,
        :_path_segments => request.symbolized_path_parameters
      ).merge(:script_name => '')
    end
  end

  module Instrumentation

    def process_action(action, *args)
      ## tableau adds :remote_ip and :session_id to the payload hash
      raw_payload = {
        :controller => self.class.name,
        :action     => self.action_name,
        :params     => request.filtered_parameters,
        :formats    => request.formats.map(&:to_sym),
        :method     => request.method,
        :path       => (request.fullpath rescue "unknown"),
        :remote_ip => request.get_remote_ip,
        :session_id => request.respond_to?(:session_options) ? request.session_options[:id] : nil
      }

      ActiveSupport::Notifications.instrument("start_processing.action_controller", raw_payload.dup)

      ActiveSupport::Notifications.instrument("process_action.action_controller", raw_payload) do |payload|
        result = super
        payload[:status] = response.status
        append_info_to_payload(payload)
        result
      end
    end
  end



end



