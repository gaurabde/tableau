# This WILL be removed when we upgrade to Rails 3.1 where the solution is bit cleaner in case we have default scopes with
# lamdas versus a regular named scope. 
# See ticket https://rails.lighthouseapp.com/projects/8994/tickets/1812-default_scope-cant-take-procs for more info.
# Well, the record_timestamp related stuff will not be removed (it was added after the above remark) 
module ActiveRecord
  class Base

    # Used to record whether or not you want to use ActiveRecord's automatic timestamping in the thread.  
    # There can be at most one entry per thread (key is the thread's id).
    AR_BASE_TIMESTAMP_SETTING ||= :ar_base_timestamp_setting

    class << self

      def inherited(child_class)
        child_class.initialize_generated_modules
        super
      end

      def initialize_generated_modules
        @attribute_methods_mutex = Mutex.new
      end

      # Overrides the built in record_timestamps method with returns true by default in ActiveRecord::Base
      # This allows a uniform value to be retrieved for all AR access in a given thread, which means that
      # thread safety is assured.
      def record_timestamps
        ts_setting = Thread.current[AR_BASE_TIMESTAMP_SETTING]
        ts_setting.nil? || ts_setting # makes default true
      end

      # Allows you to turn off ActiveRecord's automatic timestamping on a per-thread basis
      # It makes sure to empty out the entry in @@timestamp_setting when it is no longer needed
      # which avoids a minor memory leak.
      def with_no_timestamping
        begin
          ts_setting = Thread.current[AR_BASE_TIMESTAMP_SETTING]# Previous hash entry (if any)
          Thread.current[AR_BASE_TIMESTAMP_SETTING]= false # Don't record timestamps

          yield

        ensure
          if ts_setting.nil? # If it wasn't in the hash before, then remove it now
            Thread.current[AR_BASE_TIMESTAMP_SETTING] = nil
          else
            Thread.current[AR_BASE_TIMESTAMP_SETTING] = ts_setting # Set back to previous hash value
          end
        end
      end    


      def default_scope(options = {})
        reset_scoped_methods

        default_scoping = self.default_scoping.dup
        previous = default_scoping.pop

        if previous.respond_to?(:call) or options.respond_to?(:call)
          new_default_scope = lambda do
            sane_options = options.respond_to?(:call) ? options.call : options
            sane_previous = previous.respond_to?(:call) ? previous.call : previous
            construct_finder_arel sane_options, sane_previous
          end
        else
          new_default_scope = construct_finder_arel options, previous
        end

        self.default_scoping = default_scoping << new_default_scope
      end

      protected
        def current_scoped_methods
          method = scoped_methods.last
          if method.kind_of? Proc
            unscoped(&method)
          else
            method
          end
        end
    end

  end
end
