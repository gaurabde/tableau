# wgapp needs this class defined (well, hopefully not)
module ::ArJdbc
  module PostgreSQL
    class RecordNotUnique < Exception
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class JdbcAdapter < AbstractAdapter

      alias_method :execute_original, :execute

      def execute(sql, name = nil)
        tried = false
        begin
          execute_original(sql, name)
        rescue ActiveRecord::StatementInvalid
          if !tried
            tried = true
            reconnect!
            retry
          else
            raise
          end
        end

      end
    end
  end
end
