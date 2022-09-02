require 'metarecord/generator_base'
require 'metarecord/model'
require 'json'

class ManifestGenerator < GeneratorBase
  def initialize
    @manifest_data = {}
  end

  def generate output
    Model.list.each do |model|
      @manifest_data[model[:name]] = @current_manifest_item = Hash.new
      self.instance_eval &model[:block]
    end
    File.open output, 'w' do |f|
      f.write JSON.pretty_generate(@manifest_data)
    end
  end

  def property type, name, options = {}
    db_options  = options[:db] || Hash.new
    column_name = db_options[:column] || name
    db_options.delete :column
    @current_manifest_item[column_name] = { type: type, options: db_options }
  end

  def has_one type, name, options = {}
    db_options  = options[:db] || Hash.new
    column_name = db_options[:column] || "#{name}_id"
    db_options.delete :column
    @current_manifest_item[column_name] = { type: "Crails::Odb::id_type", options: db_options }
  end

  def has_many type, name, options = {}
    if options[:joined] == false
      db_options  = options[:db] || Hash.new
      column_name = db_options[:column] || "#{get_singular_name name}_id"
      db_options.delete :column
      @current_manifest_item[column_name] = { type: "INTEGER[]", options: db_options }
    end
  end
end
