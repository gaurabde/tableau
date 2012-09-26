# fixtures were all the time causing Exclusive locks in PG.  This caused problems when solr dataimporter was running.
# see http://kopongo.com/2008/7/25/postgres-ri_constrainttrigger-error
# and http://www.collectivenoodle.com/blog-articles/2009/12/8/pgerror-error-permission-denied-ri_constrainttrigger_xxxxxxx.html


#prevent database query caching if caching is turned off
require 'arjdbc/postgresql/adapter'

module ::ArJdbc
  module PostgreSQL
    def disable_referential_integrity(&block)
      transaction {
        begin
          execute "SET CONSTRAINTS ALL DEFERRED"
          yield
        ensure
          execute "SET CONSTRAINTS ALL IMMEDIATE"
        end
      }
    end
    
    def quoted_date(value) #:nodoc:
      if value.acts_like?(:time) && value.respond_to?(:usec)
        usec_value = value.usec
        usec_value = value.utc.usec if (value.respond_to? :utc) && (value.utc.respond_to? :usec) 
        "#{super}.#{sprintf("%06d", usec_value)}"
      else
        super
      end
    end
    
  end
end


