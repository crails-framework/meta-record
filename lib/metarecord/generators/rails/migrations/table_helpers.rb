require 'metarecord/generators/rails/migrations/type_helpers'

module RailsTableHelpers
  include RailsTypeHelpers

  def create_table model_name, columns
    _append "create_table :#{get_table_name model_name} do |t|"
    indent do
      columns.each do |name, options|
        record_type = get_record_type options["type"]
        if record_type.nil?
          on_unsupported_type model_name, name, options["type"]
          next
        end
        src = "t."
        src += rails_type_name record_type
        src += " :#{name}"
        src += type_options_string record_type
        src += database_options_string options
        _append src
      end
    end
    _append "end"
  end

  def create_column model_name, column_name, data
    column_operation 'create', model_name, column_name, data
  end

  def update_column model_name, column_name, data
    column_operation 'change', model_name, column_name, data
  end

  def drop_table model_name
    _append "drop_table :#{get_table_name model_name}"
  end

  def drop_column model_name, column_name
    _append "remove_column :#{get_table_name model_name}, :#{column_name}"
  end

private
  def get_table_name model_name
    get_pluralized_name model_name.underscore
  end

  def database_options_string data
    str = ""
    data["options"].each do |key, value|
      str += ", #{key}: #{value.to_json}"
    end
    str
  end

  def column_operation operation, model_name, column_name, data
    record_type = get_record_type data["type"]
    if record_type.nil?
      on_unsupported_type model_name, column_name, data["type"]
      return
    end
    src  = "#{operation}_column :#{get_table_name model_name}, :#{column_name}"
    src += ", :#{rails_type_name record_type}"
    src += type_options_string record_type
    src += database_options_string data
    _append src
  end
end
