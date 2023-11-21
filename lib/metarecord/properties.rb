class PropertyType
  def initialize name
    @name = name
  end

  def name
    @name
  end

  def parameter_type options = {}
    if (pass_by_const_reference? && options[:ref].nil?) || options[:ref]
      "const #{@name}&"
    else
      @name
    end
  end

  def pass_by_const_reference?
    true
  end
end

class PropertyTypeFromRubyType < PropertyType
  def initialize name, sourceType
    super name
    @sourceType = sourceType
  end

  def pass_by_const_reference?
    if [Float, Integer, Fixnum, Bignum, Complex, Rational].include? @sourceType
      false
    else
      true
    end
  end
end

class Boolean < PropertyType
  def initialize parent
    super(if parent.methods.include?(:nativeTypeNameFor)
      name = parent.nativeTypeNameFor ByteArray
      if name == ByteArray then default_name else name end
    else
      default_name
    end)
  end

  def default_name
    "bool"
  end

  def pass_by_const_reference?
    false
  end
end

class ByteArray < PropertyType
  def initialize parent
    super(if parent.methods.include?(:nativeTypeNameFor)
      name = parent.nativeTypeNameFor ByteArray
      if name == ByteArray then default_name else name end
    else
      default_name
    end)
  end

  def default_name
    "std::string"
  end
end

class Class
  def to_property_type parent
    if self <= PropertyType
      self.new parent
    elsif parent.methods.include? :nativeTypeNameFor
      PropertyTypeFromRubyType.new parent.nativeTypeNameFor(self), self
    else
      throw "Cannot use Class as a property type parameter with a generator that doesn't implement nativeTypeNameFor"
    end
  end
end

