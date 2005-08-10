$__instiki_source_patterns = [
  '[A-Z]*', 'instiki', 'instiki.rb', 'app/**/*', 'lib/**/*', 'vendor/**/*',
  'public/**/*', 'natives/**/*', 'config/**/*', 'script/**/*'
]

spec = Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'instiki'
  s.version = "0.10.2"
  s.summary = 'Easy to install WikiClone running on WEBrick and SQLite'
  s.description = <<-EOF
    Instiki is a Wiki Clone written in Ruby that ships with an embedded 
    webserver. You can setup up an Instiki in just a few steps. 
    Possibly the simplest wiki setup ever.
  EOF
  s.author = 'David Heinemeier Hansson'
  s.email = 'david@loudthinking.com'
  s.rubyforge_project = 'instiki'
  s.homepage = 'http://www.instiki.org'

  s.bindir = '.'
  s.executables = ['instiki']
  s.default_executable = 'instiki'

  s.has_rdoc = false
  
  s.add_dependency('RedCloth', '= 3.0.3')
  s.add_dependency('rubyzip', '= 0.5.8')
  s.add_dependency('rails', '= 0.13.1')
  s.add_dependency('sqlite3-ruby', '= 1.1.0')
  s.requirements << 'none'
  s.require_path = 'lib'

  s.files = $__instiki_source_patterns.inject([]) { |list, glob|
  	list << Dir[glob].delete_if { |path|
      File.directory?(path) or
      path.include?('.svn/') or 
      path.include?('vendor/') or 
      path.include?('test/') or
      path.include?('_test.rb')
    }
  }.flatten

end
