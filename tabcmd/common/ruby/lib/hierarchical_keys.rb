# This module provides index accessor methods for
# dot-separated hierarchical hash keys.
module HierarchicalKeys
  def [](keylist)
    if keylist.instance_of?(String)
      keylist = keylist.split('.')
    elsif _hk_atomic_key?(keylist)
      keylist = [keylist]
    end
    raise ArgumentError, "Invalid key of class #{keylist.class} found" unless keylist.instance_of?(Array)
    head_key = _hk_convert_key(keylist.shift)
    if keylist.length == 0 then
      if _hk_hash_is_self?
        super(head_key)
      else
        _hk_get_hash[head_key]
      end
    else
      if _hk_get_hash.has_key?(head_key)
        subhash = (_hk_hash_is_self?) ? super(head_key) : _hk_get_hash[head_key]
        unless subhash.instance_of?(self.class)
          raise ArgumentError, "subkey #{keylist.join('.')} applied to non-Hierhash"
        end
      else
        return subhash if subhash.nil?
      end
      subhash[keylist] 
    end
  end

  def []=(keylist, value)
    keylist = keylist.split('.') if keylist.instance_of?(String)
    raise ArgumentError, "Invalid key of class #{keylist.class} found; String or Array expected" unless keylist.instance_of?(Array)
    head_key = _hk_convert_key(keylist.shift)
    if keylist.length == 0 then
      if _hk_hash_is_self?
        super(head_key, value)
      else
        _hk_set_hash(head_key, value)
      end
    else
      if _hk_get_hash.has_key?(head_key)
        subhash = _hk_get_hash[head_key]
        unless subhash.instance_of?(self.class)
          raise ArgumentError, "subkey #{keylist.join('.')} applied to non-#{self.class}"
        end
      else
        subhash = _hk_set_hash(head_key, self.class.new)
      end
      subhash[keylist] = value
    end
  end

  # Add a new, empty sub-structure with the given key
  def <<(key)
    raise ArgumentError, "key #{key} is not atomic, so cannot be a node name" unless _hk_atomic_key?(key)
    key = _hk_convert_key(key)
    # If the key already exists, just ignore
    return self[key] if _hk_get_hash.has_key?(key)
    _hk_set_hash(key,self.class.new)
  end

  private
  def _hk_hash_is_self?
    _hk_get_hash == self
  end

  # These may be overriden by including classes to
  # obtain the desired behavior.  The defaults are
  # intended for a class that's a subclass of Hash.
  def _hk_get_hash
    self
  end
  def _hk_set_hash(k,v)
    self[k] = v
  end
  def _hk_convert_key(k)
    k
  end
  def _hk_atomic_key?(k)
    k.instance_of? String and not k.index('.')
  end
end
