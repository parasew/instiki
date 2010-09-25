begin
  require "rubygems"
  vend = File.join(File.dirname(__FILE__), '..', 'vendor')
  Gem.use_paths File.join(vend, 'bundle', File.basename(Gem.dir)), (Gem.path + [File.join(vend, 'plugins', 'bundler')])
  require "bundler"
rescue LoadError
  raise "Could not load the bundler gem. Install it with `gem install bundler`."
end

if Gem::Version.new(Bundler::VERSION) <= Gem::Version.new("0.9.24")
  raise RuntimeError, "Your bundler version is too old for Rails 2.3." +
   "Run `gem install bundler` to upgrade."
end

begin
  # Set up load paths for all bundled gems
  ENV["BUNDLE_GEMFILE"] = File.join(File.dirname(File.dirname(__FILE__)), 'Gemfile')
  Bundler.setup
rescue Bundler::GemNotFound
  raise RuntimeError, "Bundler couldn't find some gems." +
    "Did you run `bundle install`?"
end

