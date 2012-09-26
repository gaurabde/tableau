#class ERB
#  module Util
    # Original four escape sequences defined in
    # workgroup-support\jruby\lib\ruby\gems\1.8\gems\activesupport-3.0.7\lib\active_support\core_ext\string\output_safety.rb
    # HTML_ESCAPE = { '&' => '&amp;',  '>' => '&gt;',   '<' => '&lt;', '"' => '&quot;' }

    # Add two more escape sequences for extra safety
#    HTML_ESCAPE["'"] = '&#x27;'
#    HTML_ESCAPE["/"] = '&#x2F;'

    # A utility method for escaping HTML tag characters.
    # This method is also aliased as <tt>h</tt>.
    #
    # In your ERb templates, use this method to escape any unsafe content. For example:
    #   <%=h @person.name %>
    #
    # ==== Example:
    #   puts html_escape("is a > 0 & a < 10?")
    #   # => is a &gt; 0 &amp; a &lt; 10?
#    def html_escape(s)
#      s = s.to_s
#      if s.html_safe?
#        s
#      else
#        s.gsub(/[&"><'\/]/) { |special| HTML_ESCAPE[special] }.html_safe
#      end
#    end

#    remove_method(:h)
#    alias h html_escape

#    module_function :h

#    singleton_class.send(:remove_method, :html_escape)
#    module_function :html_escape

#  end
#end