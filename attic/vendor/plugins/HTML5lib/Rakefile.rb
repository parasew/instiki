require 'rake'
require 'hoe'
require 'lib/html5/version'

Hoe.new("html5", HTML5::VERSION) do |p|
  p.name = "html5"
  p.description = p.paragraphs_of('README', 2..5).join("\n\n")
  p.summary = "HTML5 parser/tokenizer."

  p.author   = ['Ryan King'] # TODO: add more names
  p.email    = 'ryan@theryanking.com'
  p.url      = 'http://code.google.com/p/html5lib'
  p.need_zip = true

  p.extra_deps << ['chardet', '>= 0.9.0']
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
end

require 'rcov/rcovtask'

namespace :test do
  namespace :coverage do
    desc "Delete aggregate coverage data."
    task(:clean) { rm_f "coverage.data" }
  end
  desc 'Aggregate code coverage for unit, functional and integration tests'
  Rcov::RcovTask.new(:coverage => "test:coverage:clean") do |t|
    t.libs << "test"
    t.test_files = FileList["test/test_*.rb"]
    t.output_dir = "test/coverage/"
    t.verbose = true
  end
end