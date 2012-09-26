# Monkey patch ConnectionPool#checkout to wait 5 seconds if no pools are available
# Source : https://github.com/rails/rails/issues/2547
# For Rails 3.2.0 and upper, You need to check if the pool error still occurs
if Rails.version < "3.2.0"
  class ActiveRecord::ConnectionAdapters::ConnectionPool
    def checkout
      # Checkout an available connection
      @connection_mutex.synchronize do
        loop do
          conn = if @checked_out.size < @connections.size
                   checkout_existing_connection
                 elsif @connections.size < @size
                   checkout_new_connection
                 end
          return conn if conn

          # No connections available; wait for one
          if @queue.wait(@timeout)
            next
          else
            # try looting dead threads
            clear_stale_cached_connections!
            if @size == @checked_out.size
              raise ActiveRecord::ConnectionTimeoutError, "could not obtain a database connection#{" within #{@timeout} seconds" if @timeout}.  The max pool size is currently #{@size}; consider increasing it."
            end
          end

        end
      end
    end
  end
end