#Rails3 this is now
module ActionDispatch
  class Request < Rack::Request
    private
    def compute_trusted_list
      [AppConfig.worker0.host, '127.0.0.1'].concat((AppConfig.gateway.trusted || "").split(',').collect{|ip| ip.gsub(' ','')})
    end

    public
    #always trust the main apache gateway and localhost.  Append any configured trusted gateways
    def trusted_gateways
      @@TRUSTED_GATEWAYS ||= compute_trusted_list
    end

    # Get the originating IP address of this request. REMOTE_ADDR contains the other
    # end of the socket, typically this is apache. So, we look at X-FORWARDED-FOR.
    # We don't blindly trust this header since it can be easily spoofed. We only unwind
    # through 'trusted' gateways.
    def get_remote_ip
      remote_addr = env['REMOTE_ADDR']
      if (env.key?('HTTP_X_FORWARDED_FOR'))
        forwards_list = env['HTTP_X_FORWARDED_FOR'].split(/, */)
        while trusted_gateways.include?(remote_addr) and forwards_list.size() > 0
          remote_addr = forwards_list.pop
        end
      end
      remote_addr
    end

    ##NOTE:  a related monkey-patch to ActionController's log_processing helper routine
    ## "request_origin" is in common/ruby/rails-hooks/hook_action_controller.rb

  end
end

module ActionDispatch
  module Http
    module URL

      #override host_with_port method to backout forwarded list
      private
      def compute_trusted_host_list
        trusted_names = [AppConfig.worker0.host, 'localhost', '127.0.0.1']

        default_port_string = ''
        default_port_string = ":#{AppConfig.gateway.port}" unless AppConfig.gateway.port == 80
        ssl_port_string = ''
        ssl_port_string = ":#{AppConfig.ssl.port}" unless AppConfig.ssl.port == 443

        #now generate the trusted list including http and https ports
        trusted = []
        trusted.concat(trusted_names.collect{|name| name+default_port_string})
        trusted.concat(trusted_names.collect{|name| name+ssl_port_string}) if AppConfig.ssl.enabled || AppConfig.ssl.login

        #construct the default public host gateway
        public_host = AppConfig.gateway.public.host
        public_ip   = IPSocket.getaddress(public_host) rescue nil
        unless AppConfig.gateway.public.port == 80 or AppConfig.gateway.public.port == 443
          public_host += ":#{AppConfig.gateway.public.port}"
          public_ip   += ":#{AppConfig.gateway.public.port}" if public_ip
        end
        trusted << public_host.downcase
        trusted << public_ip if public_ip

        #add the trusted_hosts and trusted config values and return it
        trusted.concat((AppConfig.gateway.trusted_hosts || "").split(',').collect{|name| name.gsub(' ','')})

        # B27192 also add the trusted ip addresses, in case those are used
        trusted.concat((AppConfig.gateway.trusted || "").split(',').collect{|ip| ip.gsub(' ','')})

        trusted
      end

      def hostname_resolves_to_trusted_ip?(hostname, port)
        Socket.getaddrinfo(hostname, nil, Socket::AF_INET, Socket::SOCK_STREAM).each do |entry|
          return true if trusted_hosts.include?(entry[3] + (port.nil? ? '' : ":#{port}"))
        end
        false
      rescue
        false
      end

      public
      def trusted_hosts
        @@TRUSTED_HOSTS ||= compute_trusted_host_list
      end

      def raw_host_with_port
        if forwarded = env["HTTP_X_FORWARDED_HOST"]
          forwards_list = forwarded.split(/, */)
          #find the last trusted gateway and use that as the host
          while forwards_list.size > 1
            forward_entry = forwards_list[-2].downcase
            hostpart, portpart = forward_entry.split(':')

            if trusted_hosts.include?(forward_entry)
              forwards_list.pop
            elsif hostname_resolves_to_trusted_ip?(hostpart, portpart)
              @@TRUSTED_HOSTS << forward_entry
              forwards_list.pop
            else
              break
            end
          end
          forwards_list.last
        else
           env['HTTP_HOST'] || "#{env['SERVER_NAME'] || env['SERVER_ADDR']}:#{env['SERVER_PORT']}"
        end
      end

    end
  end
end
