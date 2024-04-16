Gem::Specification.new do |s|
  s.name         = 'meta-record'
  s.version      = '1.0.13'
  s.date         = '2024-04-16'
  s.summary      = 'MetaRecord is a database code generator from Crails Framework'
  s.description  = <<DESC
  MetaRecord is a code generator that allows you to define your application
  models using a Ruby-powered DSL, and generates various implementation for
  them, for your web server, client, or mobile application.
  It can generate code for the following targests: Crails, Qt, ActiveRecord,
  Comet.cpp, and Aurelia.js.
DESC
  s.authors      = ["Michael Martin Moro"]
  s.email        = 'michael@unetresgrossebite.com'
  s.files        = `git ls-files -z`.split("\x0").select do |name|
    name.match %r{^(bin|lib)/}
  end
  s.homepage     = 'https://github.com/crails-framework/meta-record'
  s.license      = '0BSD'
  s.require_path = 'lib'
  s.bindir       = 'bin'
  s.executables << 'metarecord-make'
end
