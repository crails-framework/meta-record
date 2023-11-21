require 'metarecord/generators/qt/base'

class QtSourceGenerator < GeneratorQtBase
  def reset
    super
    @state = nil
    @relations = {}
    @fields = []
    @transients = []
    @signals = []
  end

  def generate_for object
    reset
    @class_name = object[:name]
    @inherits = object[:inherits]
    generate_constructor object
    generate_transient_members unless @transients.empty?
    generate_methods object
    @src
  end

  def super_class
    if @inherits.nil?
      self.class.super_class
    else
      @inherits
    end
  end

  def generate_constructor object
    @state = :constructor
    _append "#{@class_name}::#{@class_name}(QObject* parent) : #{super_class}(parent)"
    make_block do
      self.instance_eval &object[:block]
    end
    _append ""
  end

  def generate_transient_members
    @transients.each do |member|
      list << "{#{member.inspect}}"
    end
    _append "const QStringList #{@class_name}::virtualPropertyNames = {#{list.join ','}};"
  end

  def generate_methods object
    @state = :methods
    self.instance_eval &object[:block]
  end

  def property type, name, options = {}
    property_type = type.to_property_type(self)
    type = property_type.name
    member = "m_#{name.lower_camelcase}"
    member = options[:qt][:member] if options[:qt] && options[:qt][:member]
    getter = name.lower_camelcase
    setter = "set#{name.camelcase}"
    signal = "#{name.lower_camelcase}Changed"
    case @state
    when :constructor
      _append "connect(this, &#{@class_name}::#{signal}, this, &#{@class_name}::attributeChanged);"
      unless options[:qt].nil? || options[:qt][:member].nil?
        _append "#{member} = #{get_value options[:default]};" unless options[:default].nil?
      end
      @transients << name if options[:db] && options[:db][:transient]
    when :methods
      getter_options = if options[:qt] && options[:qt][:getter] then options[:qt][:getter] else {} end
      setter_options = if options[:qt] && options[:qt][:setter] then options[:qt][:setter] else {} end
      getter_type = property_type.parameter_type getter_options
      setter_type = property_type.parameter_type setter_options
      _append "\n#{getter_type} #{@class_name}::#{getter}() const"
      make_block do
        _append "return #{member};"
      end
      _append "\nvoid #{@class_name}::#{setter}(#{setter_type} _value)"
      make_block do
        _append "if (_value != #{member})"
        make_block do
          _append "#{member} = _value;"
          _append "Q_EMIT #{signal}();"
        end
      end
    end
  end

  def has_one type, name, options = {}
    case @state
    when :constructor
      @transients << name
    end
  end

  def has_many type, name, options = {}
    setter = "set#{name.camelcase}"
    member_name = "m_#{name.lower_camelcase}"
    signal = "#{name}Changed"
    case @state
    when :constructor
      _append "registerRelationship(\"#{name}\", #{member_name});"
    when :methods
      _append "void #{@class_name}::#{setter}(const  QList<#{type}*>& value)"
      make_block do
        _append "#{member_name} = value;"
        _append "Q_EMIT #{signal}();"
      end 
    end
  end

  def visibility name
  end

  def resource_name name
  end

  def order_by name, flow = nil
  end

  class << self
    def extension ; ".cpp" ; end

    def is_file_based? ; true ; end

    def make_file filename, data
      source = <<CPP
#include "#{filename.split('/').last[0...-3]}.h"
#{collect_includes_for(filename).join "\n"}

#{data[:bodies].join "\n"}
CPP
    end
  end
end
