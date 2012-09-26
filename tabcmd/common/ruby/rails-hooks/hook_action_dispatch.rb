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
# add 'close' to UploadedFile
# -----------------------------------------------------------------------
module ActionDispatch
  module Http
    class UploadedFile
      def close
        @tempfile.close if @tempfile
      end
    end
  end
end


module ActionDispatch
  module Routing
    class RouteSet #:nodoc:
      class Generator #:nodoc:
        def initialize(options, recall, set, extras = false)
          @script_name = options.delete(:script_name) #delete this from the options list AND
          @script_name = Site.get_script_name_func.call
          @named_route = options.delete(:use_route)
          @options     = options.dup
          @recall      = recall.dup
          @set         = set
          @extras      = extras

          normalize_options!
          normalize_controller_action_id!
          use_relative_controller!
          controller.sub!(%r{^/}, '') if controller
          handle_nil_action!
        end
      end
    end
  end
end
