require 'metarecord/model'
require 'metarecord/generator_base'

class CometArchiveGenerator < GeneratorBase
  def self.is_file_based? ; false ; end

  def reset
    @src = ""
    @declarations = []
    super
  end

  def should_generate_for_object
    (not object[:header].nil?) && (not object[:classname].nil?)
  end

  def generate_for object
    reset
    _append "#ifndef #{self.class.client_define}"
    _append "# include <crails/renderer.hpp>"
    _append "# include <crails/utils/backtrace.hpp>"
    _append "#endif"
    _append "#include <crails/archive.hpp>"
    _append "#include \"#{object[:header]}\"\n"
    _append "void #{object[:classname]}::serialize(IArchive& archive)"
    _append "{"
    @src += "  archive & id"
    self.instance_eval &object[:block]
    @src += ";\n"
    _append "}\n"

    _append "void #{object[:classname]}::serialize(OArchive& archive) const"
    _append "{"
    @src += "  archive & id"
    self.instance_eval &object[:block]
    @src += ";\n"
    _append "}"

    generate_archive_views object
  end

  def generate_archive_views object
    @src += "\n"
    ptr_type = "#{object[:classname]}*"
    funcname_prefix = "render_#{object[:classname].gsub(/^::/,'').underscore}"
    funcname = "#{funcname_prefix}_show_archive"
    _append "#ifndef #{self.class.client_define}"
    _append "void #{funcname}(const Crails::Renderer&, Crails::RenderTarget& target, Crails::SharedVars& vars)"
    _append "{"
    @indent += 1
    _append "auto* model = Crails::cast<#{ptr_type}>(vars, \"model\");"
    _append "OArchive archive;\n"
    _append "if (model)"
    _append "  model->serialize(archive);"
    _append "else"
    _append "  throw boost_ext::runtime_error(\"Called #{funcname} with null model\");"
    _append "target.set_body(archive.as_string());"
    @indent -= 1
    _append "}\n"

    funcname = "#{funcname_prefix}_index_archive"
    _append "void #{funcname}(const Crails::Renderer&, Crails::RenderTarget& target, Crails::SharedVars& vars)"
    _append "{"
    @indent += 1
    _append "auto* models = Crails::cast<std::vector<#{object[:classname]}>*>(vars, \"models\");"
    _append "OArchive archive;\n"
    _append "archive & (*models);"
    _append "target.set_body(archive.as_string());"
    @indent -= 1
    _append "}"
    _append "#endif"
  end

  def property type, name, options = {}
    return if should_skip_on_client? options
    @src += " & #{name}"
  end

  def has_one type, name, options = {}
    return if should_skip_on_client? options
    if options[:joined] != false
      @src += " & #{name}"
    else
      @src += " & #{name}_id"
    end
  end

  def has_many type, name, options = {}
    return if should_skip_on_client? options
    singular_name = get_singular_name name
    if options[:joined] != false
      @src += " & #{name}"
    else
      @src += " & #{singular_name}_ids"
    end
  end

  class << self
    def client_define
      "__COMET_CLIENT__"
    end

    def extension ; ".archive.cpp" ; end

    def make_file filename, data
      source = ""
      source += (collect_includes_for filename).join("\n")
      source += "\n" + (data[:bodies].join "\n")
      source
    end
  end
end
