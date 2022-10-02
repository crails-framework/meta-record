require 'metarecord/generators/crails/data_generator'

class CometDataGenerator < CrailsDataGenerator
  def generate_class_head object
    _append_macro "#ifndef #{self.class.client_define}"
    super object
    _append_macro "#else"
    _append "struct #{object[:name]} : public #{self.class.client_super_class}"
    _append_macro "#endif"
  end

  def prepare_order_by
    _append_macro "#ifndef #{self.class.client_define}"
    super
    _append_macro "#endif"
  end

  def edit_resource_declaration
    with_visibility :protected do
      _append_macro "#ifdef #{self.class.client_define}"
      _append "#{id_type} id = #{null_id};"
      _append_macro "#endif"
    end
    _append_macro "#ifdef #{self.class.client_define}"
    _append "#{id_type} get_id() const { return id; }"
    _append "void         set_id(#{id_type} value) { id = value; }"
    _append "void         from_json(Data data);"
    _append "virtual std::vector<std::string> find_missing_parameters(Data) const;"
    _append "virtual void                     edit(Data);"
    _append "virtual void                     merge_data(Data) const;"
    _append "virtual std::string              to_json() const;"
    _append "virtual bool                     is_valid();"
    _append_macro "#else"
    super
    _append_macro "#endif"
    _append ""
  end

  def resource_name name
    super name
    _append_macro "#ifdef #{self.class.client_define}"
    _append "std::string get_resource_name() const { return scope; }"
    _append_macro "#endif"
  end

  def has_many_fetch list_type, name, options
    with_visibility :public do
      _append_macro "#ifdef #{self.class.client_define}"
      _append "Comet::Promise fetch_#{name}();"
      _append_macro "#else"
      _append "void fetch_#{name}();"
      _append_macro "#endif"
    end
  end

  class << self
    def client_define
      "__COMET_CLIENT__"
    end

    def client_super_class
      "MODELS_CLIENT_SUPER_CLASS"
    end

    def generate_includes
<<CPP
#{super}
#ifdef #{client_define}
# include <comet/mvc/model.hpp>
# include <comet/mvc/archive_model.hpp>
# include <comet/promise.hpp>
# ifndef #{client_super_class}
#  define #{client_super_class} Comet::JsonModel<>
# endif
#endif
CPP
    end
  end
end
