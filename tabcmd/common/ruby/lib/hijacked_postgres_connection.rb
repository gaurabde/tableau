# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2011 Tableau Software, Incorporated
#                    and its licensors. All rights reserved.
# Protected by U.S. Patent 7,089,266; Patents Pending.
#
#
# Inspired by simple_postgres_connection, but able to work from a jar
# (success attributed to ActiveRecord magic)
#
# -----------------------------------------------------------------------

require 'delayed_retry'
require 'java'
require 'jdbc/postgres'
require 'active_record'
require 'starting_up_exception'

java_import java.sql.DriverManager

class HijackedPostgresConnection

  def initialize(host, port, dbname, dbuser='rails')

    conn = {
      :adapter => 'jdbcpostgresql',
      :database => dbname,
      :username =>  dbuser,
      :password => '',
      :host => host,
      :port => port
#,      :schema_search_path =>  'public'
    }

    @conn = @connection_pool = nil
    delayed_retry(:exceptions => [NativeException, StartingUpException], :delay => 3) do
      #when we make the connection, the return is a not-helpful connection-pool
      begin
        @connection_pool = ActiveRecord::Base.establish_connection(conn)
      rescue Exception => e
        if e.to_s.downcase.index("the database system is starting up")
          raise StartingUpException
        else
          raise
        end
      end
    end

    # seems necessary to ask for the connection from ActiveRecord::Base, not the pool
    delayed_retry(:exceptions => [NativeException, StartingUpException], :delay => 3) do
      #when we make the connection, the return is a not-helpful connection-pool
      begin
        @conn = ActiveRecord::Base.connection
      rescue Exception => e
        if e.to_s.downcase.index("the database system is starting up")
          raise StartingUpException
        else
          raise
        end
      end
    end
  end

  def execute_query(sql)
    rs = @conn.execute(sql)
    return rs
  end

  def execute_update(sql)
    @conn.update(sql)
  end

  def close
    @conn.disconnect!
    @conn = nil #we don't wrap reconnect, so might as well defend against our further use now
  end
end
