require 'metarecord/generator_base'
require 'metarecord/manifest_generator'

module MetaRecordRunner
  def manifest_path
    ".metarecord-manifest.json"
  end

  def run_all
    @generators.each do |generator|
      require "metarecord/generators/#{generator.to_s}_generator"
    end
    `rm -Rf #{@tmpdir} && mkdir -p #{@tmpdir}`
    GeneratorBase.prepare @input, @tmpdir, @base_path
    GeneratorBase.odb_connection = @odb_connection
    ManifestGenerator.new.generate "#{@tmpdir}/#{manifest_path}"
    @old_manifest = JSON.parse File.read(manifest_path) rescue {}
    @new_manifest = JSON.parse File.read("#{@tmpdir}/#{manifest_path}")
    @generators.each do |generator|
      const_name = generator.to_s.camelcase + "Generator"
      klass      = Kernel.const_get const_name
      GeneratorBase.use klass
      if klass.new.should_generate_from_manifest
        klass.new.generate_manifest @old_manifest, @new_manifest
      end
    end
    update_files
  end

  def update_files
    `cp "#{@tmpdir}/#{manifest_path}" "#{manifest_path}"`

    Dir["#{@tmpdir}/**/*"].each do |tmp_file|
      next if File.directory? tmp_file
      new_path = "#{@output}/#{tmp_file[@tmpdir.size + 1..tmp_file.size]}"
      if (not File.exists?(new_path)) || File.read(new_path) != File.read(tmp_file)
        puts "[metarecord] generated #{new_path}"
        `mkdir -p '#{File.dirname new_path}'`
        `cp '#{tmp_file}' '#{new_path}'`
      else
        puts "[metarecord] no updates required for #{new_path}"
      end
    end

    @input.each do |input|
      Dir["#{@output}/#{input}/**/*"].each do |actual_file|
        next if File.directory? actual_file
        tmp_path = "#{@tmpdir}/#{@output[@output.size + 1..@output.size]}"
        if not File.exists?(tmp_path)
          puts "[metarecord] removed #{actual_file}"
          `rm '#{actual_file}'`
        end
      end
    end
  end
end
