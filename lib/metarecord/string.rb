require_relative './properties'

class String
  def underscore
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end

  def camelcase
    return self if self !~ /_/ && self =~ /[A-Z]+.*/
    split(/_|\//).map{|e| e.capitalize}.join
  end

  def lower_camelcase
    upperCamelcase = camelcase
    upperCamelcase[0].downcase + upperCamelcase[1..-1]
  end

  def to_property_type parent
    if parent.methods.include? :nativeTypeNameFor
      PropertyType.new(parent.nativeTypeNameFor self)
    else
      PropertyType.new self
    end
  end
end
