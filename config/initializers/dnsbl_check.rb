require 'dnsbl_check'
ActionController::Base.send :include, DNSBL_Check
