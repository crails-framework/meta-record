require 'metarecord/generators/crails/edit_generator'

class CometEditGenerator < CrailsEditGenerator
  def _append_macro str
    @src ||= ""
    @src += str + "\n"
  end

  def generate_json_methods object
    super
    @rendering_from_json = true
    _append_macro "#ifdef #{CometDataGenerator.client_define}"
    _append "void #{@klassname}::from_json(Data data)"
    _append "{"
    @indent += 1
    _append "id = data[\"id\"].defaults_to<#{id_type}>(#{null_id});"
    _append "edit(data);"
    @indent -= 1
    _append "}"
    _append_macro "#endif"
    @rendering_from_json = false
  end

  def validation type, name, data
    if data[:uniqueness] == true
      _append_macro "#ifndef #{CometDataGenerator.client_define}"
      _append validate_uniqueness type, name
      _append_macro "#endif"
      data[:uniqueness] = false
    end
    super type, name, data
  end

  def has_one_getter type, name, options
    type = get_type type
    tptr = ptr_type type
    _append_macro "#ifndef #{CometDataGenerator.client_define}"
    super
    _append_macro "#else"
    _append "#{tptr} #{@klassname}::get_#{name}() const"
    _append "{"
    _append "  #{tptr} model = std::make_shared<#{type}>();"
    _append "  model->set_id(get_#{name}_id());"
    _append "  model->fetch();"
    _append "  return model;"
    _append "}"
    _append_macro "#endif"
  end

  def joined_has_one_edit type, name, options
    data_id     = "data[\"#{name}_id\"]"
    inline_data = "data[\"#{name}\"]"
    _append_macro "#ifndef #{CometDataGenerator.client_define}"
    super
    _append_macro "#else"
    _append "{"
    _append "  if (#{data_id} == 0)"
    _append "    set_#{name}(nullptr);"
    _append "  else if (!get_#{name}() || #{data_id} != get_#{name}()->get_id())"
    _append "  {"
    _append "    auto linked_resource = std::make_shared<#{type}>();"
    _append "    linked_resource->set_id(#{data_id}.as<#{id_type}>());"
    _append "    set_#{name}(linked_resource);"
    _append "  }"
    _append "}"
    _append "else if (#{inline_data}.exists())"
    _append "{"
    _append "  auto linked_resource = std::make_shared<#{type}>();"
    _append "  linked_resource->from_json(#{inline_data});"
    _append "  set_#{name}(linked_resource);"
    _append "}"
    _append_macro "#endif"
  end

  def has_many_fetch type, name, options
    tptr = ptr_type type
    singular_name = get_singular_name name

    _append_macro "#ifndef #{CometDataGenerator.client_define}"
    super type, name, options
    _append_macro "#else"
    _append "Comet::Promise #{@klassname}::fetch_#{name}()"
    _append "{"
    @indent += 1
    _append "std::vector<Comet::Promise> promises;\n"
    _append "for (auto id : #{singular_name}_ids)"
    _append "{"
    @indent += 1
    _append "#{tptr} model;\n"
    _append "model->set_id(id);"
    _append "promises.push_back(model->fetch());"
    _append "#{name}.push_back(model);"
    _append "#{name}_fetched = true;"
    @indent -= 1
    _append "}"
    _append "return Comet::Promise::all(promises);"
    @indent -= 1
    _append "}"
    _append_macro "#endif"
  end

  def property type, name, options = {}
    if options[:ready_only] == true && rendering_edit?
      options[:read_only] = false
      _append_macro "#ifdef #{CometDataGenerator.client_define}"
      super
      _append_macro "#endif"
    else
      super
    end
  end

  def has_many type, name, options = {}
    if options[:read_only] == true && rendering_edit?
      options[:read_only] = false
      _append_macro "#ifdef #{CometDataGenerator.client_define}"
      super
      _append_macro "#endif"
    else
      super
    end
  end

  def has_one type, name, options = {}
    if options[:read_only] == true && rendering_edit?
      options[:read_only] = false
      _append_macro "#ifdef #{CometDataGenerator.client_define}"
      super
      _append_macro "#endif"
    else
      super
    end
  end

  class << self
    def generate_includes
<<CPP
#ifndef #{CometDataGenerator.client_define}
#{super}
#else
# include <crails/odb/helpers.hpp>
#endif
CPP
    end

    def sourcefile_to_destfile sourcefile
      base      = super sourcefile
      basepath  = Pathname.new base
      parentdir = basepath.dirname.to_s + "/shared"
      "#{parentdir}/#{basepath.basename}"
    end
  end
end
