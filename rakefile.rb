begin
  require 'rubygems'
  require 'rake/gempackagetask'
rescue Exception
  nil
end

ENV['RAILS_ENV'] = 'test'
require 'config/environment'

require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/packagetask'
require 'rake/contrib/rubyforgepublisher'
require 'code_statistics'

desc 'Default Task'
task :default => :test

CLEAN << 'pkg' << 'storage/2500' << 'doc' << 'html'

# Run the unit tests
Rake::TestTask.new { |t|
  t.libs << 'libraries'
  t.libs << 'app/models'
  t.libs << 'vendor/bluecloth-1.0.0/lib'
  t.libs << 'vendor/madeleine-0.7.1/lib'
  t.libs << 'vendor/RedCloth-3.0.3/lib'
  t.libs << 'vendor/rubyzip-0.5.6'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
}

if defined? GemPackageTask
  gemspec = eval(File.read('instiki.gemspec'))
  Rake::GemPackageTask.new(gemspec) do |p|
    p.gem_spec = gemspec
    p.need_tar = true
    p.need_zip = true
  end

# PKG_VERSION is defined in instiki.gemspec
  Rake::PackageTask.new("instiki", gemspec.version) do |p|
    p.need_tar = true
    p.need_zip = true
    # the list of glob expressions for files comes from instiki.gemspec
    p.package_files.include($__instiki_source_patterns) 
  end
  
# Create a task to build the RDOC documentation tree.
  rd = Rake::RDocTask.new("rdoc") { |rdoc|
    rdoc.rdoc_dir = 'html'
    rdoc.title = 'Instiki -- The Wiki'
    rdoc.options << '--line-numbers --inline-source --main README'
    rdoc.rdoc_files.include(gemspec.files)
    rdoc.main = 'README'
  }
else
  puts "Warning: without Rubygems packaging tasks are not available"
end

desc "Publish RDOC to RubyForge"
task :rubyforge => [:rdoc, :package] do
    Rake::RubyForgePublisher.new('instiki', 'alexeyv').upload
end

desc "Report code statistics (KLOCs, etc)"
task :stats do
  CodeStatistics.new(
    ["Helpers", "app/helpers"], 
    ["Controllers", "app/controllers"], 
    ["Functionals", "test/functional"],
    ["Models", "app/models"],
    ["Units", "test/unit"],
    ["Libraries", "libraries"]
  ).to_s
end

