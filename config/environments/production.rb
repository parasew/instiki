# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.cache_classes = true

# Use a different logger for distributed setups
# config.logger        = SyslogLogger.new

####
# This rotates the log file, keeping 25 files, of 1MB each.

config.action_controller.logger = Logger.new(Rails.root.join('log', "#{RAILS_ENV}.log"), 25, 1024000)

# Unfortunately, the above does not work well under Mongrel, as the default Ruby logger class
# does no locking and you will have several processes running, each wanting to write to (and 
# rotate) the log file. One solution is to have each mongrel instance writes to a different log file:
#   http://blog.caboo.se/articles/2006/11/14/configure-mongrel-rails-logger-per-port for a solution.
# Another is to use the default logging behaviour (comment out the above line)
# and use an external program (e.g. logrotate) to rotate the logs.
####

# Full error reports are disabled and caching is turned on
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true
config.action_view.cache_template_loading            = true

# Enable serving of images, stylesheets, and javascripts from an asset server
# config.action_controller.asset_host                  = "http://assets.example.com"

# Disable delivery errors if you bad email addresses should just be ignored
# config.action_mailer.raise_delivery_errors = false
