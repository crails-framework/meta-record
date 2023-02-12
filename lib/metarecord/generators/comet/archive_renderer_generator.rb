require 'metarecord/generator_base'
require 'metarecord/generators/rails/migrations/table_helpers'

class CometArchiveRendererGenerator < GeneratorBase
  def should_generate_for object
    false
  end

  def should_generate_from_manifest
    true
  end

  def generate_manifest old_manifest, new_manifest
    reset
    @indent = 2
    @declarations = ""
    new_manifest.keys.each do |model_name|
      add_model model_name
    end
    @indent = 0
    make_renderer
  end

private
  def add_model model
    name = model.gsub(/^::/,'').underscore
    funcname_prefix = "render_#{name}"
    funcname = "#{funcname_prefix}_show_archive"
    @declarations += "std::string #{funcname}(const Crails::Renderer& renderer, Crails::RenderTarget& target, Crails::SharedVars& vars);\n"
    _append "templates.insert("
    _append "  pair<string, Generator>(\"#{name}/show\", #{funcname})"
    _append ");"
    funcname = "#{funcname_prefix}_index_archive"
    @declarations += "std::string #{funcname}(const Crails::Renderer& renderer, Crails::RenderTarget& target,  Crails::SharedVars& vars);\n"
    _append "templates.insert("
    _append "  pair<string, Generator>(\"#{name}/index\", #{funcname})"
    _append ");"
  end

  def make_renderer
    filepath = "lib/renderers/archive.cpp"
    src = <<CPP
#include <crails/renderers/archive_renderer.hpp>
#include <crails/archive.hpp>

using namespace Crails;
using namespace std;

#{@declarations}

ArchiveRenderer::ArchiveRenderer()
{
#{@src}
}
CPP
    File.open filepath, 'w' do |f|
      f.write src
    end
    puts "[metarecord][archive/renderer] Generated renderer file #{filepath}"
  end
end
