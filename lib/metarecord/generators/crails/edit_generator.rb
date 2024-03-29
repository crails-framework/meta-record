require 'metarecord/model'
require 'metarecord/generator_base'
require 'metarecord/generators/crails/helpers/validations'

class CrailsEditGenerator < GeneratorBase
  def reset
    super
    @required_params = []
  end

  def generate_for object
    @modelname = object[:name].underscore
    @klassname = get_classname(object)
    reset
    generate_edit_method object
    generate_json_methods object
    generate_parameter_validator object
    generate_relations object
    @src
  end

  def generate_relations object
    @rendering_has_many = true
    self.instance_eval &object[:block]
    @rendering_has_many = false
  end

  def generate_edit_method object
    _append "void #{@klassname}::edit(Data data)"
    _append "{"
    @indent += 1
    self.instance_eval &object[:block]
    @indent -= 1
    _append "}\n"
  end

  def generate_json_methods object
    @rendering_to_json = true
    _append "void #{@klassname}::merge_data(Data data) const"
    _append "{"
    @indent += 1
    self.instance_eval &object[:block]
    @indent -= 1
    _append "}\n"
    _append "std::string #{@klassname}::to_json() const"
    _append "{"
    @indent += 1
    _append "DataTree data;\n"
    _append "merge_data(data);\n"
    _append "return data.to_json();"
    @indent -= 1
    _append "}\n"
    @rendering_to_json = false
  end

  def generate_parameter_validator object
    _append "std::vector<std::string> #{@klassname}::find_missing_parameters(Data data) const"
    _append "{"
    @indent += 1
    if @required_params.size > 0
      _append "return data.find_missing_keys({#{@required_params.join ','}});"
    else
      _append "return {};"
    end
    @indent -= 1
    _append "}"

    _append "bool #{@klassname}::is_valid()"
    _append "{"
    @indent += 1
    _append "errors.clear();"
    @rendering_validations = true
    self.instance_eval &object[:block]
    @rendering_validations = false
    _append "return errors.as_data().get_keys().size() == 0;"
    @indent -= 1
    _append "}"
  end

  def resource_name name
    if @rendering_has_many
      _append "const std::string #{@klassname}::scope = #{name.to_s.inspect};"
      _append "const std::string #{@klassname}::plural_scope = #{(get_pluralized_name name.to_s).inspect};"
      _append "const std::string #{@klassname}::view = \"${view-placeholder}/data/#{@modelname}\";"
    end
  end

  def rendering_edit?
    not ([@rendering_has_many, @rendering_validations, @rendering_to_json].include? true)
  end

  def property type, name, options = {}
    if @rendering_validations && !options[:validate].nil?
      validation type, name, options[:validate]
    elsif @rendering_to_json
      case type
      when "DataTree"     then _append "data[\"#{name}\"].merge(#{name});"
      when "LocaleString" then _append "data[\"#{name}\"] = #{name}.to_string();"
      else                     _append "data[\"#{name}\"] = #{name};"
      end
    elsif options[:read_only] != true && rendering_edit?
      setter = "set_#{name}(data[\"#{name}\"]);"
      setter = "set_#{name}(data[\"#{name}\"].as<int>());" if not (type =~ /^(unsigned)?\s*char$/).nil?
      if options[:required] == true
        @required_params.push  "\"#{name}\""
	_append setter
      else
        _append "if (data[\"#{name}\"].exists())"
        @indent += 1
        _append setter
        @indent -= 1
      end
    end
  end

  def validation type, name, data
    if !data[:min].nil?
      _append validate_number_min name, data[:min]
    end
    if !data[:max].nil?
      _append validate_number_max name, data[:max]
    end
    if data[:required] == true
      _append validate_required type, name
    end
    if data[:self_reference] == true
      _append validate_self_reference type, name
    end
    if data[:uniqueness] == true
      puts "/!\\ WARNING: uniqueness validations not available for crails generators"
      #_append validate_uniqueness type, name
    end
  end

  def has_one_getter type, name, options
    type = get_type type
    tptr = ptr_type type
    _append "#{tptr} #{@klassname}::get_#{name}() const"
    _append "{"
    _append "  #{GeneratorBase.odb_connection[:object]} database;"
    _append "  #{tptr} result;\n"
    _append "  database.find_one(result, #{name}_id);"
    _append "  return result;"
    _append "}\n"
  end

  def has_one_setter type, name, options
    type = get_type type
    tptr = ptr_type type
    _append "void #{@klassname}::set_#{name}(#{tptr} v)"
    _append "{"
    _append "  #{name}_id = v != nullptr ? v->get_id() : #{null_id};"
    _append "}\n"
  end

  def joined_has_one_edit type, name, options
    tptr = ptr_type type
    data_id = "data[\"#{name}_id\"]"
    _append "{"
    _append "  if (#{data_id} == #{null_id})"
    _append "    set_#{name}(nullptr);"
    _append "  else if (!get_#{name}() || #{data_id} != get_#{name}()->get_id())"
    _append "  {"
    _append "    #{GeneratorBase.odb_connection[:object]} database;"
    _append "    #{tptr} linked_resource;"
    _append "    database.find_one(linked_resource, data[\"#{name}_id\"].as<#{id_type}>());"
    _append "    set_#{name}(linked_resource);"
    _append "  }"
    _append "}"
  end

  def has_one type, name, options = {}
    type = get_type type
    tptr = ptr_type type
    if @rendering_has_many
      if options[:joined] == false
        has_one_getter type, name, options
        has_one_setter type, name, options
      else
        _append "#{id_type} #{@klassname}::get_#{name}_id() const"
        _append "{"
        _append "  return #{name} ? #{name}->get_id() : #{null_id};"
        _append "}\n"
      end
    elsif @rendering_validations
      if not options[:validate].nil?
        if options[:joined] == false
          validation "#{id_type}", "#{name}_id", options[:validate]
        else
          validation tptr, name, options[:validate]
        end
      end
    elsif @rendering_to_json
      if options[:joined] == false
        _append "data[\"#{name}_id\"] = get_#{name}_id();"
      else
        _append "if (#{name} != nullptr)"
        _append "  data[\"#{name}_id\"] = get_#{name}_id();"
      end
    elsif options[:read_only] != true
      data_id = "data[\"#{name}_id\"]"
      _append "if (#{data_id}.exists())"
      if options[:joined] != false
        joined_has_one_edit type, name, options
      else
        _append "set_#{name}_id(data[\"#{name}_id\"]);"
      end
    end
  end

  def has_many type, name, options = {}
    type = get_type type
    if @rendering_has_many
      if options[:joined] != false
        _join_based_has_many type, name, options
      else
        _id_based_has_many type, name, options
      end
      _append "void #{@klassname}::collect_#{name}(std::map<#{id_type}, #{ptr_type type}>& results)"
      _append "{"
      @indent += 1
      _append "for (auto model : get_#{name}())"
      _append "{"
      @indent += 1
      _append "if (results.find(model->get_id()) == results.end())"
      _append "  results[model->get_id()] = model;"
      @indent -= 1
      _append "}"
      @indent -= 1
      _append "}"
    elsif @rendering_validations
    elsif @rendering_to_json
      _append "data[\"#{get_singular_name name}_ids\"].from_vector<#{id_type}>(get_#{get_singular_name name}_ids());"
    elsif options[:read_only] != true
      data = "data[\"#{get_singular_name name}_ids\"]"
      _append "if (#{data}.exists())"
      _append "  update_#{name}(#{data});"
    end
  end

  def _join_based_has_many type, name, options
    tptr = ptr_type type
    list_type = "std::list<#{tptr} >"
    singular_name = get_singular_name name
    _append "std::vector<#{id_type}> #{@klassname}::get_#{singular_name}_ids() const"
    _append "{"
    @indent += 1
    _append "return collect_ids_from(get_#{name}());"
    @indent -= 1
    _append "}\n"

    _append "bool #{@klassname}::update_#{name}(Data ids)"
    _append "{"
    @indent += 1
    _append "return update_id_list<#{type}>(#{name}, ids);"
    @indent -= 1
    _append "}\n"

    _append "void #{@klassname}::add_#{singular_name}(#{tptr} resource)"
    _append "{"
    @indent += 1
    _append "remove_#{singular_name}(*resource);"
    _append "#{name}.push_back(resource);"
    @indent -= 1
    _append "}\n"

    _append "void #{@klassname}::remove_#{singular_name}(const #{type}& resource)"
    _append "{"
    @indent += 1
    _append "#{name}.remove_if([&resource](#{tptr} comp)"
    _append "{"
    @indent += 1
    _append "return comp->get_id() == resource.get_id();"
    @indent -= 1
    _append "});"
    @indent -= 1
    _append "}\n"
  end

  def _id_based_has_many type, name, options
    tptr = ptr_type type
    singular_name = get_singular_name name

    _append "bool #{@klassname}::update_#{name}(Data ids)"
    _append "{"
    @indent += 1
    _append "return update_id_list<#{type}>(this->#{singular_name}_ids, ids);"
    @indent -= 1
    _append "}\n"

    _append "void #{@klassname}::add_#{singular_name}(#{tptr} v)"
    _append "{"
    @indent += 1
    _append "remove_#{singular_name}(*v);"
    _append "#{singular_name}_ids.push_back(v->get_id());"
    @indent -= 1
    _append "}\n"

    _append "void #{@klassname}::remove_#{singular_name}(const #{type}& v)"
    _append "{"
    @indent += 1
    _append "auto it = remove_if(#{singular_name}_ids.begin(), #{singular_name}_ids.end(), [v](#{id_type} id)"
    _append "{"
    @indent += 1
    _append "return id == v.get_id();"
    @indent -= 1
    _append "});"
    _append "if (it != #{singular_name}_ids.end())"
    @indent += 1
    _append "#{singular_name}_ids.erase(it);"
    @indent -= 2
    _append "}\n"

    _append "const std::list<#{tptr} >& #{@klassname}::get_#{name}()"
    _append "{"
    @indent += 1
    _append "if (!#{name}_fetched)"
    @indent += 1
    _append "fetch_#{name}();"
    @indent -= 1
    _append "return #{name};"
    @indent -= 1
    _append "}\n"

    has_many_fetch type, name, options
  end

  def has_many_fetch type, name, options
    singular_name = get_singular_name name

    _append "void #{@klassname}::fetch_#{name}()"
    _append "{"
    @indent += 1
    _append "typedef odb::pgsql::query<#{type}> query;"
    _append "#{GeneratorBase.odb_connection[:object]} database;"
    _append "odb::result<#{type}> results;"
    _append "#{name}.clear();"
    _append "database.find<#{type}>(results,"
    _append "  query::id + \"=\" + Crails::Odb::any(#{singular_name}_ids, \"int\")"
    _append ");"
    _append "for (auto model : results)"
    _append "  #{name}.push_back(std::make_shared<#{type}>(model));"
    _append "#{name}_fetched = true;"
    @indent -= 1
    _append "}\n"
  end

  class << self
    def extension ; ".cpp" ; end

    def generate_includes
      source  = "#include <crails/odb/helpers.hpp>\n"
      source += "#include <crails/odb/any.hpp>\n"
      source += "#include <#{GeneratorBase.odb_connection[:include]}>\n"
      source += "#include \"lib/odb/application-odb.hxx\"\n"
    end

    def make_file filename, data
      base = "lib/" + filename[0...-3]
      include = base + ".hpp"
      data[:bodies].each do |body|
        body.gsub! "${view-placeholder}", base.split("/")[0...-2].join("/")
      end
      source  = "#include \"#{include}\"\n"
      source += generate_includes
      source += (collect_includes_for filename).join "\n"
      source += "\n\n" + (data[:bodies].join "\n")
    end
  end
end
