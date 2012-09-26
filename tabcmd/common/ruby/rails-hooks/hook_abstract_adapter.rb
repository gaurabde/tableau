# This should be removed once upgraded to version > 3.1.
# This is a monkey patch to make query cache thread safe
# BUGZID: 48901

if Rails.version < "3.1.0"
  module ActiveRecord
    module ConnectionAdapters
      class AbstractAdapter
        alias_method :old_initialize, :initialize

        def initialize(connection, logger=nil)
          @query_cache_mutex = Mutex.new
          old_initialize(connection, logger)
        end
      end
    end
  end
end