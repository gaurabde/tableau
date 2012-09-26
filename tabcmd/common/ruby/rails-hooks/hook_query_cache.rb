# This should be removed once upgraded to version > 3.1.
# This is a monkey patch to make query cache thread safe
# BUGZID: 48901

if Rails.version < "3.1.0"
  module ActiveRecord
      module ConnectionAdapters
        module QueryCache

            def query_cache_mutex
              # just in case mutex is not initialized yet
              @query_cache_mutex ||= Mutex.new
            end

            def clear_query_cache
              query_cache_mutex.synchronize do
                @query_cache.clear
              end
            end

            private
            def cache_sql(sql)
              result = query_cache_mutex.synchronize do
                if @query_cache.has_key?(sql)
                  ActiveSupport::Notifications.instrument("sql.active_record",
                                                          :sql => sql, :name => "CACHE", :connection_id => self.object_id)
                  @query_cache[sql]
                else
                  @query_cache[sql] = yield
                end
              end
              if Array === result
                result.collect { |row| row.dup }
              else
                result.duplicable? ? result.dup : result
              end
            rescue TypeError
              result
            end

          end
      end
  end
end