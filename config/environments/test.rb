Dependencies.mechanism = :require
ActionController::Base.consider_all_requests_local = true
ActionController::Base.perform_caching = false

require 'fileutils'
FileUtils.mkdir_p(RAILS_ROOT + "/log")

unless defined? TEST_LOGGER
  timestamp = Time.now.strftime('%Y%m%d%H%M%S')
  log_name = RAILS_ROOT + "/log/instiki_test.#{timestamp}.log"
  $stderr.puts "To see the Rails log:\n    less #{log_name}"
  
  TEST_LOGGER = ActionController::Base.logger = Logger.new(log_name)
  INSTIKI_DEBUG_LOG = true unless defined? INSTIKI_DEBUG_LOG
  
  WikiService.storage_path = RAILS_ROOT + '/storage/test/'
end
