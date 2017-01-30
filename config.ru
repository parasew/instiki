# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)
run Instiki::Application

# Was:
#
# # RAILS_ROOT/config.ru
# require File.join(File.dirname(__FILE__), 'config', 'boot')
# require File.join(File.dirname(__FILE__), 'config', 'environment')
# require 'active_support'
# require 'action_controller'
# use Rails::Rack::LogTailer
# use Rails::Rack::Static
# run ActionController::Dispatcher.new
