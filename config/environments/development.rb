Dependencies.mechanism = :require
ActionController::Base.consider_all_requests_local = true
ActionController::Base.perform_caching = false
BREAKPOINT_SERVER_PORT = 42531
INSTIKI_DEBUG_LOG = true unless defined? INSTIKI_DEBUG_LOG
