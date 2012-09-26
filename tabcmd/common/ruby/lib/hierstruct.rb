require 'ostruct'
require 'hierarchical_keys'

class HierStruct < OpenStruct
  include HierarchicalKeys

  attr_reader :table

  def initialize(hash=nil)
    @table = {}
    replace(hash)
  end
  
  # Produce a 'flattened' single-level hash with dot-separated keys
  # from this HierStruct.
  def flatten
    _flatten
  end

  def replace(hash=nil)
    @table.each_key do |k|
	# JRuby fails to parse "java.*" options in yml files, so skip if option begins with "java".
      _singleton_class.send(:remove_method,k) unless k.to_s.eql?("java")
      _singleton_class.send(:remove_method,"#{k}=") unless k.to_s.eql?("java")
    end
    @table = hash.nil? ? {} : _unflatten(hash)
    @table.each { |k,v| _new_hs_member(k) }
  end
  
  def new_node(name)
    name = name.to_sym
    @table[name] = self.class.new
    _new_hs_member(name)
  end

  # Implement initialize_copy such that all internal
  # nodes are dup'ed, which matches the logical 
  # semantics of a mapping to a flat hash with 
  # dot-separated keys.
  def initialize_copy(orig)
    super
    copies = {}
    @table.each { |k, v| copies[k] = v.dup if v.instance_of? HierStruct }
    @table = @table.merge! copies
  end

  def method_missing(m_id, *args, &block)
    mname = m_id.id2name
    len = args.length
    if mname =~ /=$/
      if len != 1
        raise ArgumentError, "wrong number of arguments (#{len} for 1)", caller(1)
      end
      if self.frozen?
        raise TypeError, "can't modify frozen #{self.class}", caller(1)
      end
      mname.chop!
      self._new_hs_member(mname)
      @table[mname.intern] = args[0]
    elsif len == 0
      if block_given?
        @table[m_id] = block
        block.call
      else
        _get_table_value(m_id)
      end
    else
      raise NoMethodError, "undefined method `#{mname}' for #{self}", caller(1)
    end
  end
  
  alias_method :hk_orig_index, :[]
  def [](key)
    value = hk_orig_index(key)
    value.respond_to?(:call) ? value.call : value    
  end
  
  protected
  def _singleton_class
    class << self; self; end
  end

  def _new_hs_member(name)
    name = name.to_sym
    unless self.respond_to?(name)
      instance_eval <<EOM
      def #{name}(&block)
        if block_given?
          @table[:#{name}] = block
        else
          _get_table_value(:#{name})
        end
      end
EOM
      _singleton_class.send(:define_method, :"#{name}=") do |x| 
        @table[name] = x
      end
    end
  end
  
  # This masks whether there's a direct or lazy value stored
  # at the given node
  def _get_table_value(name)
    value = @table[name]
    value.respond_to?(:call) ? value.call : value    
  end

  def _internal_node?(name)
    name = name.to_sym
    @table[name].instance_of? HierStruct
  end
  
  def _flatten(result={},prefix='')
    prefix << '.' unless prefix.empty?
    @table.each do |k,v|
      case v
      when HierStruct
        v._flatten(result,"#{prefix}#{k}")
      else
        result["#{prefix}#{k}"] = v
      end
    end
    result
  end
  
  # Given a flat hash with dot-separated structured keys,
  # turn it into a hash where subkey-nodes are HierStructs
  def _unflatten(hash)
    new_hs = self.class.new
    hash.each do |k, v|
      new_hs[k] = v
    end
    new_hs.table
  end
  
  private
  def _hk_get_hash
    @table
  end
  
  def _hk_set_hash(k,v)
    _new_hs_member(k)
    @table[_hk_convert_key(k)] = v
  end
  
  def _hk_convert_key(k)
    k.to_sym
  end
  
  alias_method :_hierstruct_orig_atomic_key?, :_hk_atomic_key?
  def _hk_atomic_key?(k)
    k.instance_of? Symbol or _hierstruct_orig_atomic_key?(k)
  end

  # This function can be called in an erb template that uses a HierStruct's
  # binding, as our config machinery does.  # Helper function here allows us to
  # escape parens from apache's DirectoryMatch regexps in httpd.conf # If we
  # don't do this, the parens are treated as regexp groups, instead of # path
  # compenents.  Since we often deploy in "....Program Files (x86)"... this is
  # actually a problem
  def escape_from_regexp(s)
    return s.gsub('(','\(').gsub(')','\)')
  end
end
