require 'metarecord/model'
require 'metarecord/generator_base'

class AureliaGenerator < GeneratorBase
  def reset
    super
    @state = nil
    @relations = {}
    @fields = []
  end

  def generate_for object
    reset
    @class_name = object[:name] + "Data"
    generate_class        object
    generate_global_scope object
    generate_fields       object
    @src
  end

  def generate_global_scope object
    @state = :global_scope
    self.instance_eval &object[:block]
  end

  def generate_class object
    _append "export class #{@class_name} extends Model {"
    @indent += 1
    _append "constructor() {"
    _append "  super();"
    _append "}"

    @state = :class_scope
    self.instance_eval &object[:block]
    @indent -= 1
    _append "}\n"
  end

  def generate_fields object
    @state = :field_scope
    _append "#{@class_name}.fields = ["
    @indent += 1
    @fields = []
    self.instance_eval &object[:block]
    @indent -= 1
    @src += "\n"
    _append "];"
    _append "Fields.inject(#{@class_name}.fields);"
    _append "#{@class_name}.fields._mapFields();"
  end

  def order_by name
    if @state == :global_scope
      _append "#{@class_name}.defaultOrderBy = \"#{name}\""
    end
  end

  def property type, name, options = {}
    return if not options[:client].nil? and options[:client][:ignore] == true
    if @state == :field_scope
      type = cppToJsType type
      unless options[:client].nil?
        type = options[:client][:type] unless options[:client][:type].nil?
      end
      @src += ",\n" if @fields.count > 0
      field = { name: name, type: type }
      field[:default] = options[:default] if not options[:default].nil?
      if not options[:validate].nil?
        field[:min]      = options[:validate][:min] unless options[:validate][:min].nil?
        field[:max]      = options[:validate][:max] unless options[:validate][:max].nil?
        field[:required] = options[:validate][:required] unless options[:validate][:required].nil?
      end
      @fields << field
      _append field.to_json, no_line_return: true
    end
  end

  def has_one type, name, options = {}
    return if options[:client] == false
    type = type.split("::").last
    if @state == :field_scope
      @src += ",\n" if @fields.count > 0
      
      field = { name: "#{name}_id", type: type, label: name }
      if not options[:validate].nil?
         field[:required] = options[:validate][:required] unless options[:validate][:required].nil?
      end
      @fields << field
      _append field.to_json, no_line_return: true
    end
  end

  def has_many type, name, options = {}
    return if options[:client] == false
    type = type.split("::").last
    if @state == :field_scope
      @src += ",\n" if @fields.count > 0
      @fields << ({
        name: "#{get_singular_name name}_ids",
        type: "array[#{type}]",
        label: name
      })
      _append @fields.last.to_json, no_line_return: true
    end
  end

  def resource_name name
    if @state == :global_scope
      _append "#{@class_name}.scope = \"#{name}\";"
    end
  end

  def cppToJsType type
    case type
    when 'std::string'    then 'string'
    when 'std::time_t'    then 'timestamp'
    when 'unsigned long'  then 'integer'
    when 'unsigned short' then 'integer'
    when 'unsigned char'  then 'integer'
    when 'unsigned int'   then 'integer'
    when 'long'           then 'integer'
    when 'short'          then 'integer'
    when 'char'           then 'integer'
    when 'int'            then 'integer'
    when 'DataTree'       then 'object'
    when 'LocaleString'   then 'locale-string'
    else type
    end
  end

  class << self
    def extension ; ".js" ; end

    def is_file_based? ; false ; end

    def model_import_path
      if defined? METARECORD_AURELIA_MODEL_IMPORT
        METARECORD_AURELIA_MODEL_IMPORT
      else
        "aurelia-metarecord"
      end
    end

    def make_file filename, data
      src  = "import {Model} from '#{model_import_path}';\n"
      src += "import {Fields} from 'aurelia-metarecord';\n\n"
      src + (data[:bodies].join "\n")
    end
  end
end
