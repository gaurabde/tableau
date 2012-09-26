module ActiveRecord
  class SessionStore
    class Session
      alias_method :old_marshal_data!, :marshal_data!
      def data
        @data ||= self.class.unmarshal(read_attribute(@@data_column_name)) || {}
        @data['vizql_data'] ||= SessionInfo.new(false, lambda { read_attribute('shared_vizql_write') })
        @data['wg_data'] ||= SessionInfo.new(true, lambda { read_attribute('shared_wg_write') } )
        return @data
      end
    private
      def marshal_data!
        return false unless loaded?
        if @data['wg_data'] && @data['wg_data'].dirty?
          write_attribute('shared_wg_write', @data['wg_data'].marshal)
        end
        @data['wg_data'] = nil
        @data['vizql_data'] = nil
        write_attribute(@@data_column_name, self.class.marshal(@data))
      end
    end
  end
end

class SessionInfo 
  def initialize(writable, data)
    @data = data if data.is_a?(Proc)
    @writable = writable
    @dirty = false
    @loaded = false
  end

  def dirty?
    @dirty
  end

  def hash
    return @data if @loaded
    @loaded = true
    text = (@data && @data.call) || nil
    @data = (text && ActiveSupport::JSON.decode(text)) ||  {}
  end

  def marshal
    ActiveSupport::JSON.encode(@data) if @dirty
  end

  def get(name)
    hash[name]
  end

  def set(name, value)
    return unless @writable
    @dirty = true
    hash[name] = value
  end  
end