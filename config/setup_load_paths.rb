require "rubygems"
vend = File.join(File.dirname(__FILE__), '..', 'vendor')
Gem.use_paths File.join(vend, 'bundle', File.basename(Gem.dir)), (Gem.path + [File.join(vend, 'plugins', 'bundler')])
