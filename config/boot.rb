ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" if File.exist?(ENV["BUNDLE_GEMFILE"])

# Rails 6.1 + Ruby 3.x: ActiveSupport autoloads Logger, then expects
# Logger::Severity to be defined eagerly. Without this require, boot fails.
require "logger"
