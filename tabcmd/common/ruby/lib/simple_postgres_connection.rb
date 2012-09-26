# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2011 Tableau Software, Incorporated
#                    and its licensors. All rights reserved.
# Protected by U.S. Patent 7,089,266; Patents Pending.
# -----------------------------------------------------------------------

require 'delayed_retry'
require 'java'
require 'jdbc/postgres'

java_import java.sql.DriverManager

class SimplePostgresConnection

  def initialize(host, port, dbname, dbuser='rails')
    @conn_str = "jdbc:postgresql://#{host}:#{port}/#{dbname}"
    @dbuser = dbuser

    delayed_retry(:exceptions => [NativeException], :delay => 3) do
      @conn = DriverManager.get_connection(@conn_str, @dbuser, '')
    end
  end

  def execute_query(sql)
    rs = @conn.create_statement.execute_query(sql)

    col_names = []
    num_cols = rs.getMetaData.getColumnCount
    (1..num_cols).each { |n| col_names << rs.getMetaData.getColumnName(n) }

    result = []
    while( rs.next )
      row = {}
      (1..num_cols).each { |n|
        row[col_names[n-1]] = rs.getString(n)
      }

      result << row
    end

    result
  end

  def execute_update(sql)
    @conn.create_statement.execute_update(sql)
  end

  def close
    @conn.close
  end
end
