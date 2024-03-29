require 'metarecord/runner'

Dir["config/metarecord.rb"].each do |file|
  require "#{Dir.pwd}/#{file}"
end

module ::Guard
  class MetaRecord < Plugin
    include MetaRecordRunner

    def initialize options = {}
      super
      @base_path      = options[:base_path]
      @input          = options[:input]
      @output         = options[:output]
      @generators     = options[:generators]
      @odb_connection = options[:odb_connection]
      @input          = [@input] if @input.class != Array
      @tmpdir         = ".tmp"
    end
  end
end
