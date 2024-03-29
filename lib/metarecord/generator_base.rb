require 'pathname'
require 'json'
require_relative './string'
require_relative './properties'

class GeneratorBase
  def self.is_file_based? ; true ; end

  class << self
    attr_accessor :odb_connection

    def prepare inputs_dir, output_dir, base_path
      @base_path = base_path
      @output_dir = output_dir
      Includes.reset
      Model.reset
      inputs_dir.each do |input_dir|
        load_all_models input_dir
      end
    end

    def use generator_class
      if generator_class.is_file_based?
        _use_by_files generator_class
      else
        _use_by_models generator_class
      end
    end

    def _use_by_models generator_class
      Model.list.each do |model|
        generator = generator_class.new
        next unless generator.should_generate_for(model)
        data = { bodies: [generator.generate_for(model)] }
        data[:headers] = [generator.get_headers] if generator.methods.include? :get_headers
        source = generator_class.make_file model[:filename], data
        dirname = File.dirname model[:filename]
        dirname.gsub! /^#{@base_path}/, '' unless @base_path.nil?
        filepath = "#{@output_dir}/" + dirname
        filename = model[:name].underscore + generator_class.extension
        `mkdir -p #{filepath}`
        File.open "#{filepath}/#{filename}", 'w' do |f|
          f.write source
        end
      end
    end

    def _use_by_files generator_class
      files = {}
      Model.list.each do |model|
        generator = generator_class.new
        next unless generator.should_generate_for(model)
        files[model[:filename]] ||= {}
        filedata = files[model[:filename]]
        filedata[:headers] ||= []
        filedata[:bodies]  ||= []
        filedata[:bodies]  << generator.generate_for(model)
        if generator.methods.include? :get_headers
          filedata[:headers] << generator.get_headers
        end
      end
      files.each do |key,value|
        source = generator_class.make_file key, value
        path   = generator_class.sourcefile_to_destfile key
        path.gsub! /^#{@base_path}/, '' unless @base_path.nil?
        `mkdir -p #{@output_dir}/#{File.dirname path}`
        File.open "#{@output_dir}/#{path}", 'w' do |f|
          f.write source
        end
      end
    end

    def sourcefile_to_destfile sourcefile
      sourcepath = Pathname.new(sourcefile)
      extension  = sourcepath.extname
      sourcefile[0...-extension.length] + self.extension
    end
  end

  def should_generate_for object
    true
  end

  def should_generate_from_manifest
    false
  end

  def reset
    @tab_size = 2
    @indent = 0
    @src = ""
  end

  def indent &block
    @indent += 1
    block.call
    @indent -= 1
  end

  def unindent &block
    @indent -= 1
    block.call
    @indent += 1
  end

  def make_block delimiters = '{}', &block
    _append delimiters[0] if delimiters.size > 0
    indent &block
    _append delimiters[1] if delimiters.size > 1
  end

  def _append str, opts = {}
    @src += " " * (@indent * @tab_size)
    @src += str
    @src += "\n" unless opts[:no_line_return]
  end

  def ptr_type type
    "std::shared_ptr<#{type}>"
  end

  def get_value value
    if value.class == Symbol
      value.to_s
    else
      value.inspect
    end
  end

  def get_type type
    type = "::#{type}" unless type.start_with? "::"
    type += " " if type[type.size - 1] == ">"
    type
  end

  def get_singular_name name
    if not (name =~ /ies$/).nil?
      name[0...name.size-3] + "y"
    elsif (name =~ /(s|x)es$/).nil?
      name[0...name.size-1]
    else
      name[0...name.size-2]
    end
  end

  def get_pluralized_name name
    if not (name =~ /holiday/i).nil?
      name + "s"
    elsif not (name =~ /y$/).nil?
      name[0...name.size-1] + "ies"
    elsif not (name =~ /(s|x)$/).nil?
      name + "es"
    else
      name + "s"
    end
  end

  def get_classname object
    "#{METARECORD_NAMESPACE}::#{object[:name]}"
  end

  def id_type
    if defined? METARECORD_ID_TYPE
      METARECORD_ID_TYPE
    else
      "Crails::Odb::id_type"
    end
  end

  def null_id
    if defined? METARECORD_NULL_ID
      METARECORD_NULL_ID
    else
      "ODB_NULL_ID"
    end
  end

  def visibility name ;; end
  def resource_name name ;; end
  def order_by name, flow = nil ;; end
  def property type, name, options = {} ;; end
  def has_one type, name, options = {} ;; end
  def has_many type, name, options = {} ;; end

  def should_skip_on_client? options
    (not options[:client].nil?) && options[:client][:ignore] == true
  end
end

class GeneratorCppBase < GeneratorBase
  def nativeTypeNameFor type
    if type.class == Class
      case type.name
      when 'String'    then 'std::string'
      when 'ByteArray' then 'std::string'
      when 'Hash'      then 'DataTree'
      when 'DateTime'  then 'std::time_t'
      when 'Integer'   then 'int'
      when 'Float'     then 'float'
      when 'Boolean'   then 'bool'
      else type
      end
    else
      type
    end
  end
end
