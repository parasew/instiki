require_relative "config/application"

Rails.application.load_tasks

require "rake/testtask"

namespace :test do
  Rake::TestTask.new(:units) do |t|
    t.libs << "lib" << "test"
    t.test_files = FileList["test/unit/**/*_test.rb"]
    t.warning = false
  end

  Rake::TestTask.new(:functionals) do |t|
    t.libs << "lib" << "test"
    t.test_files = FileList["test/functional/**/*_test.rb"]
    t.warning = false
  end

  Rake::TestTask.new(:integration) do |t|
    t.libs << "lib" << "test"
    t.test_files = FileList["test/integration/**/*_test.rb"]
    t.warning = false
  end
end

desc "Run unit, functional, and integration tests"
task test: ["test:units", "test:functionals", "test:integration"]
