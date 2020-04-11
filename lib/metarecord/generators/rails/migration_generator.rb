require 'metarecord/generator_base'
require 'metarecord/generators/rails/migrations/table_helpers'

class RailsMigrationGenerator < GeneratorBase
  include RailsTableHelpers

  def should_generate_for object
    false
  end

  def should_generate_from_manifest
    true
  end

  def generate_manifest old_manifest, new_manifest
    reset
    @indent = 2
    probe_additions old_manifest, new_manifest
    probe_deletions old_manifest, new_manifest
    @indent = 0
    if @src.length > 0
      make_migration
    else
      puts "[metarecord][rails/migration] no migrations to generate"
    end
  end

private
  def have_column_changed? old_column, new_column
    old_column["type"] != new_column["type"] || old_column["options"] != new_column["options"]
  end

  def probe_additions old_manifest, new_manifest
    new_manifest.keys.each do |model_name|
      old_table = old_manifest[model_name]
      new_table = new_manifest[model_name]

      # If table does not exist, create it
      if old_table.nil?
        create_table model_name, new_table
      # If table exists, check if some of its columns have been modified
      else
        new_table.keys.each do |column_name|
          old_column = old_table[column_name]
          new_column = new_table[column_name]
          # If column does not exist, create it
          if old_column.nil?
            create_column model_name, column_name, new_column
          # If column exists, ensure none of its options have been changed
          elsif have_column_changed? old_column, new_column
            update_column model_name, column_name, new_column
          end
        end
      end
    end
  end

  def probe_deletions old_manifest, new_manifest
    old_manifest.keys.each do |model_name|
      new_table = new_manifest[model_name]
      old_table = old_manifest[model_name]

      if new_table.nil?
        drop_table model_name
      else
        old_table.keys.each do |column_name|
          new_column = new_table[column_name]
          drop_column model_name, column_name if new_column.nil?
        end
      end
    end
  end

  def make_migration
    now = DateTime.now
    timestamp = DateTime.now.strftime "%Y%m%d%H%M%S"
    filepath = "db/migrate/#{timestamp}_metarecord_generator_#{timestamp}.rb"
    src = <<RUBY
class MetarecordGenerator#{timestamp} < ActiveRecord::Migration[6.0]
  def change
#{@src}  end
end
RUBY
    File.open filepath, 'w' do |f|
      f.write src
    end
    puts "[metarecord][rails/migration] Generated migration file #{filepath}"
  end
end
