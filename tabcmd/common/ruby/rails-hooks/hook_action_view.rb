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
# This file monkey-patches Rails asset_tag_helper for static_asset_versioning
# It inserts the current static asset version (set by environment.rb and pushed into ENV)
# into the path
# -----------------------------------------------------------------------



module ActionView
  module Helpers #:nodoc:
    module AssetTagHelper

      ## the module defines constants before Rails has loaded, which means that static_asset_version is not yet known
      ## The static_asset_version support needs vizql dll's, and in some cases (generation) AppConfig, so this api
      ## to provide a way for rails's environment.rb to setup its stuff first (appconfig and static_asset_version)
      ## then make sure the asset tag handlers get the right path contants.  Or should we say, semi-constants?
      def AssetTagHelper::update_constant_directory_paths()
        if $static_asset_version && !$static_asset_version.empty?
            assets_dir = (defined?(Rails.public_path) ? Rails.public_path : "public") + '/' + $static_asset_version
            Rails.application.config.assets_dir = assets_dir
            Rails.application.config.javascripts_dir = "#{assets_dir}/javascripts"
            Rails.application.config.stylesheets_dir = "#{assets_dir}/stylesheets"
        else
          puts "$static_asset_version was NIL or Empty !!"
        end
      end

        ## RAILS3 version
      # Add the the extension +ext+ if not present. Return full URLs otherwise untouched.
      # Prefix with <tt>/dir/</tt> if lacking a leading +/+. Account for relative URL
      # roots. Rewrite the asset path for cache-busting asset ids. Include
      # asset host, if configured, with the correct request protocol.
        # for some reason config.assets_dir doesn't have the static version in it, so use $asset_base_path instead
        # if something else depends on the config.assets_dir haveing the version in it, we should investigate why it's not there
        def rewrite_extension?(source, dir, ext)
          source_ext = File.extname(source)[1..-1]
          ext && (source_ext.blank? || (ext != source_ext && File.exist?(File.join($asset_base_path, dir, "#{source}.#{ext}"))))
            end

        def compute_public_path(source, dir, ext = nil, include_host = true)
          return source if is_uri?(source)

          source += ".#{ext}" if rewrite_extension?(source, dir, ext)
                source = "/#{dir}/#{source}" unless source[0] == ?/
                unless source =~ /\/images\/custom\/.*/
                  source = "#{$static_asset_version.nil? ? '' : ('/' + $static_asset_version)}#{source}"
                end
          source = rewrite_asset_path(source, config.asset_path)

          has_request = controller.respond_to?(:request)
                if !$cdn_prefix.nil? && source !~ %r{^/#{$cdn_prefix}/}
                  source = "/#{$cdn_prefix}#{source}"
          elsif has_request && include_host && source !~ %r{^#{controller.config.relative_url_root}/}
                  #source = "#{controller.config.relative_url_root}#{source}"
                  source
                  end
          source = rewrite_host_and_protocol(source, has_request) if include_host

          source
                end


#         # Add the the extension +ext+ if not present. Return full URLs otherwise untouched.
#         # Prefix with <tt>/dir/</tt> if lacking a leading +/+. Account for relative URL
#         # roots. Rewrite the asset path for cache-busting asset ids. Include
#         # asset host, if configured, with the correct request protocol.
#         def compute_public_path(source, dir, ext = nil, include_host = true)
#           has_request = @controller.respond_to?(:request)

#           cache_key =
#             if has_request
#               [ @controller.request.protocol,
#                 ActionController::Base.asset_host.to_s,
#                 @controller.request.relative_url_root,
#                 dir, source, ext, include_host ].join
#             else
#               [ ActionController::Base.asset_host.to_s,
#                 dir, source, ext, include_host ].join


#           ActionView::Base.computed_public_paths[cache_key] ||=
#             begin
#               source += ".#{ext}" if ext && File.extname(source).blank? || File.exist?(File.join(ASSETS_DIR, dir, "#{source}.#{ext}"))

#               if source =~ %r{^[-a-z]+://}
#                 source
#               else
#                 source = "/#{dir}/#{source}" unless source[0] == ?/
#                 source = "#{$static_asset_version.nil? ? '' : ('/' + $static_asset_version)}#{source}"
#                 if !$cdn_prefix.nil? && source !~ %r{^/#{$cdn_prefix}/}
#                   source = "/#{$cdn_prefix}#{source}"
#                 elsif has_request
#                   unless source =~ %r{^#{@controller.request.relative_url_root}/}
#                     source = "#{@controller.request.relative_url_root}#{source}"
#                   end
#                 end

#                 rewrite_asset_path(source)
#               end
#             end

#           source = ActionView::Base.computed_public_paths[cache_key]
# #puts "$static_asset_verison is #{$static_asset_version}, compute_public_path for #{source}"

#           if include_host && source !~ %r{^[-a-z]+://} || source !~ %r{^[-a-z]+://}
#             host = compute_asset_host(source)

#             if has_request && !host.blank? && host !~ %r{^[-a-z]+://}
#               host = "#{@controller.request.protocol}#{host}"
#             end

#             "#{host}#{source}"
#           else
#             source
#           end
#         end

    end

  end
end
