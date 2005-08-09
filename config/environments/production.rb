Dependencies.mechanism = :require
ActionController::Base.consider_all_requests_local = false
ActionController::Base.perform_caching = false


spam_patterns_filename = RAILS_ROOT + '/config/spam_patterns.txt'
if File.exists? spam_patterns_filename
  SPAM_PATTERNS = File.readlines(spam_patterns_filename).select { |line| line != '' }.map { 
      |line| Regexp.new(line) }
end

blocked_ips_filename = RAILS_ROOT + '/config/blocked_ips.txt'
if File.exists? blocked_ips_filename
  BLOCKED_IPS = File.readlines(blocked_ips_filename).select { |line| line != '' }
end
