require 'metarecord/model'
require 'metarecord/generator_base'

class RailsDataGenerator < GeneratorBase
  def model_base_class
    "ActiveRecord::Base"
  end
  
  def generate_for object
    reset
    _append "class #{object[:name]} < #{model_base_class}"
    indent do
      _append "self.abstract_class = true"
      _append ""
      self.instance_eval &object[:block]
    end
    _append "end"
  end

  def validation type, name, data
    src = "validates #{name.to_s.inspect}"
    src += ", presence: true"   if data[:required] == true
    src += ", uniqueness: true" if data[:uniqueness] == true
    if !data[:min].nil? || !data[:max].nil?
      src += validation_numericality name, data
    end
    _append src
  end

  def validation_numericality name, data
    src = ", numericality: { "
    if !data[:min].nil?
      src += "greater_than_or_equal_to: #{data[:min]}"
    end
    if !data[:max].nil?
      src += ", " if !data[:min].nil?
      src += "less_than_or_equal_to: #{data[:max]}"
    end
    src += " }"
    src
  end

  def visibility value
  end

  def resource_name name
    _append "RESOURCE_NAME = #{name.to_s.inspect}"
  end

  def order_by name
    _append "scope :default_order, -> { order(#{name.to_s.inspect}) }"
  end

  def property type, name, options = {}
    has_custom_column_name = options[:column].nil?
    rails_name = (options[:column] || name).to_s
    if type == 'DataTree'
      _append "store #{rails_name.inspect}, coder: JSON"
      _append "def #{name} ; self.#{rails_name} ; end" if has_custom_column_name
    elsif has_custom_column_name
      _append "def #{name}"
      indent do _append "self.#{options[:column]}" end
      _append "end"
      _append "def #{name}=(value)"
      indent do _append "self.#{options[:column]} = value"end
      _append "end"
    end
    validation type, rails_name, options[:validate] unless options[:validate].nil?
  end

  def has_one type, name, options = {}
    db_options  = options[:db] || {}
    foreign_key = db_options[:column] || "#{name}_id"
    if options[:joined] != false
      _append "belongs_to #{name.to_s.inspect},"
      indent do
        optional = if db_options[:null].nil? then true else db_options[:null] end
        _append "class_name: #{type.to_s.inspect},"
        _append "foreign_key: #{foreign_key.to_s.inspect},"
        _append "optional: #{optional}"
      end
    else
      _append "has_one #{name.to_s.inspect},"
      indent do
        _append "class_naem: #{type.to_s.inspect},"
        _append "foreign_key: #{foreign_key.to_s.inspect}"
      end
    end
  end

  def has_many type, name, options = {}
    db_options = options[:db] || {}
    if options[:joined] != false
      _append "has_many #{name.inspect}"
    else
      throw "id based has_many is not supported by the rails generator"
    end
  end

  class << self
    def extension ; ".rb" ; end

    def make_file filename, data
      <<RUBY
module #{METARECORD_NAMESPACE}
  #{data[:bodies].join "\n"}
end
RUBY
    end
  end
end
