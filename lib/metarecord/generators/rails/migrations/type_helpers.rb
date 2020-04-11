module RailsTypeHelpers
  def get_record_type type
    case type
    when "ODB::id_type"       then :bigint
    when "char"               then :tinyint
    when "unsigned char"      then :smallint
    when "short"              then :smallint
    when "unsigned short"     then :mediumint
    when "int"                then :integer
    when "unsigned int"       then :integer
    when "long"               then :bigint
    when "long long"          then :bigint
    when "unsigned long"      then :bigint
    when "unsigned long long" then :bigint
    when "double"             then :float
    when "long double"        then :float
    when "float"              then :float
    when "bool"               then :boolean
    when "std::string"        then :string
    when "std::time_t"        then :timestamp
    else nil
    end
  end

  def on_unsupported_type model_name, column_name, type_name
    puts "[metarecord][rails-migration] unsupported type #{type_name} for column `#{column_name}` in table `#{model_name}`"
  end

  def is_integer_type? type
    [:tinyint, :smallint, :mediumint, :bigint, :integer].include? type
  end

  def rails_type_name type
    if is_integer_type? type then "integer" else type.to_s end
  end

  def type_options_string type
    if is_integer_type? type
      table = { tinyint: 1, smallint: 2, mediumint: 3, integer: 4, bigint: 8 }
      ", limit: #{table[type]}"
    else
      ""
    end
  end
end
