require 'form_spam_protection'
require File.join(File.dirname(__FILE__), 'vendor/enkoder/lib/enkoder')
require File.join(File.dirname(__FILE__), "/test/mocks/enkoder") if Rails.env == 'test'
ActionController::Base.send :include, FormSpamProtection