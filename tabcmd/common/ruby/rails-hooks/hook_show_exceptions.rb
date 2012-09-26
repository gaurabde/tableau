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
#
# This file replaces mixins/error_handling in pre 7.0 codelines
# due to changes in Rails3's regular and failsafe exception handling
#
# Rails2 had much exception handling in the ActionController hierarchy
# which provided convenient access to mixins, helpers, and the standard template-locating logic
#
# Rails3 moves much of this to Middleware and ActionView, which means
# 1) helpers and mixins are unavailable
# 2) the standard template/layout logic knows about fewer paths and thus
# 3) what little template/layout finding logic does exist needs full paths here and referring to partials
#
#


module ActionDispatch
  # This middleware rescues any exception returned by the application and renders
  # nice exception pages if it's being rescued locally.
  class ShowExceptions



    ## we always render exceptions as if we are NOT local.
    ## that way developers see what customers see.
    def rescue_action(exception)
      if (ENV['RAILS_ENV'] != 'development')
        rescue_action_in_public(exception)
      else
        super
      end
    end

    private

    ## We always render exceptions as if we were "in public", which has nothing to do with Beaker
    ## but instead determines what sort of data to show to the user (e.g. no stack traces, minimal leakage...)
    ##
    def render_exception(env, exception)
      log_error(exception)

      request = Request.new(env)
      rescue_action_in_public(request, exception)
    rescue Exception => failsafe_error
      $stderr.puts "Error during failsafe response: #{failsafe_error}\n  #{failsafe_error.backtrace * "\n  "}"
      FAILSAFE_RESPONSE
    end


    # overridden rescue_action_in_public passes to method that is sensitive to formats
    #
    def rescue_action_in_public(request, exception)
      render_multiformat_exception(request, exception)
    end




    ## helper routines copied from mixins + helpers since we can't see them....
    ##--------------------------------------------------------------------------
    def handling_ajax?(request)
      return ("XMLHttpRequest" == request.env["HTTP_X_REQUESTED_WITH"])
    end

    def formatted_request_id_string(request)
      msg = ''
      req_id = request.env["HTTP_X_REQUEST_ID"]
      if ((!req_id.nil?) && (!req_id.empty?))
        msg = (I18n.t 'errors.labels.formatted_request_id', :request_id => h(req_id))
      end
      msg.html_safe
    end

    def formatted_request_id_msg(request)
      msg = formatted_request_id_string(request)
      msg = "<p class=\"Textinsidetable\">#{msg}</p>" if (msg != '')
      msg.html_safe
    end

    def strip_html(message)
      if (message.respond_to? :join)
        html = message.join("\n")
      else
        html = message.to_s
      end
      Hpricot(html).inner_text
    end



    # the real work
    #------------------------------------------------------------------------------

    # Renders an exception in one of many formats
    def render_multiformat_exception(request, exception)
      Log4r.log_exception(exception, logger, :info)

      status = 500
      if ConfigurationSupport.is_beaker?
        case exception
        when VizqlDll::PublicValidationException
          @message = I18n.t 'errors.internal_error.publishing'
          @details = exception.message
          status = 200 #desktop needs a success code and then xml containing <error>
        else
          @title="Oops"
          @message = I18n.t('errors.internal_error.internal', :wgserver_name => AppCustomization.wgserver.name)
          @details = ''
        end
      else
        case exception
          # A StatementInvalid exception might contain SQL, so don't show it.
        when ActiveRecord::StatementInvalid
          @message = I18n.t('errors.internal_error.read_write', :wgserver_name => AppCustomization.wgserver.name)
          @details = ""

        when ScriptError, StandardError
          # I have no idea why I can't just include this above, but I can't :(
          if exception.class.name == "ActionController::RoutingError"
            @message = I18n.t('errors.internal_error.request.message', :wgserver_name => AppCustomization.wgserver.name)
            @details = I18n.t('errors.internal_error.request.details', :fullpath => request.fullpath)
            status = 404
          else
            @message = I18n.t('errors.internal_error.internal', :wgserver_name => AppCustomization.wgserver.name)
            @details = exception.message
          end

        when Exception
          @message = I18n.t('errors.internal_error.unknown', :wgserver_name => AppCustomization.wgserver.name)
          @details = exception.message
        end
      end


      if request.format #seems like unexpected format strings get lost along the chain
        case request.format.to_sym
        when :html
          render_html_exception(exception, @message, @details, status, request)
        else # :xml and everything else
          render_xml_exception(exception, @message, @details, status, request)
        end
      else
        render_xml_exception(exception, @message, @details, status, request)
      end
    end


    ## A few tricks for the html response:
    ## 1) Paths must be explicit from the search-path-roots which we setup here
    ##      In source-mode, Rails.root is sufficient.
    ##      In war-mode, we must find the root of the unpacked source-files
    ## 2) We always need a layout, even if it is empty.  So js/xhr use the (empty) xml layout
    ##
    ## 3) Cache-busting must be explicitly specified here to avoid problems downstream
    ##
    def render_html_exception(exception, msg, details, status, request)
      if exception.is_a?(ActionController::RoutingError)
        render_opts = {:template => ConfigurationSupport.is_beaker? ? "shared/failsafe_public_404" : "shared/failsafe_404", :status => status}
      else
        render_opts = {:template => ConfigurationSupport.is_beaker? ? "shared/failsafe_public_500" : "shared/failsafe_500", :status => status}
      end

      old_asset_id = ENV["RAILS_ASSET_ID"]
      begin
        ## specify the cache-busting environment variable to prevent ActionView problems later
        ENV["RAILS_ASSET_ID"] = rand(99999).to_s #something has gone wrong, don't depend on any cache-busting being in place

        ## we must have a layout, even if it is an empty one (for beaker/rjs)
        ## so decide which one we will show.
        ## layouts seem to need to start with a slash so that they can be found....
        if (handling_ajax?(request) || ConfigurationSupport.is_beaker?)
          layout = '/app/views/shared/failsafe.xml.templ' #basically an empty layout
        else
          layout = '/app/views/shared/failsafe.html.templ'
        end

        template_paths = [AppConfig.wgserver.root]
        ## if we're running from the warfile, then we need to add the path to the unpacked server-source.
        ## the easiest way is relative to this file
        if ConfigurationSupport.running_from_war?
          template_paths << File.expand_path(File.join(__FILE__, '../../../..'))
        end
        template = ActionView::Base.new(template_paths)

        file = "app/views/" + render_opts[:template]+".html" #patch up path so that it'll work in this context
        body = template.render(:file => file,
                               :layout => layout,
                               :locals =>  {
                                 :formatted_request_id_msg => formatted_request_id_msg(request),
                                 :formatted_request_id_string => formatted_request_id_string(request),
                                 :message => @message,
                                 :details => @details
                               })
      ensure
        ENV["RAILS_ASSET_ID"] = old_asset_id
      end
      [status, {'Content-Type' => 'text/html', 'Content-Length' => body.bytesize.to_s}, [body]]

    end



    # Renders an XML exception
    #
    def render_xml_exception(exception, msg,details,status, request)

      template = ActionView::Base.new([AppConfig.wgserver.root])

      file = "app/views/shared/failsafe.xml"
      body = template.render(:file => file,
                             :layout => "/app/views/shared/failsafe.xml.templ",
                             :locals =>  {
                               :formatted_request_id_string => formatted_request_id_string(request),
                               :message => strip_html(msg),
                               :details => strip_html(details)
                             })
      [status, {'Content-Type' => 'text/xml', 'Content-Length' => body.bytesize.to_s}, [body]]
    end

  end #class
end #module
