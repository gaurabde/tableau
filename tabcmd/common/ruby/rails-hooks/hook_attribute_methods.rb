# This was added for BUGZID:46819 and should be removed once upgrading to >= rails 3.2.1

module ActiveModel
  module AttributeMethods
    module ClassMethods
      alias_method :old_define_attribute_methods, :define_attribute_methods
      def define_attribute_methods(attr_names)
        unless (@attribute_methods_mutex.nil?)
          # This will make define_old_attribute_methods thread-safe
          # and get rid of initialization errors under heavy load
          @attribute_methods_mutex.synchronize do
            self.old_define_attribute_methods(attr_names)
          end
        else
          # I have never observed @attribute_methods_mutex be nil
          # but it is possible so this is just a safety measure
          # not to break everything for an edge case.
          self.old_define_attribute_methods(attr_names)
        end
      end
    end
  end
end
