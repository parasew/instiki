#####
# Bootstrap the Rails environment, frameworks, and default configuration
####

# Make sure we are using the latest rexml
rexml_versions = ['', 'vendor/plugins/rexml/lib/'].collect { |v| 
  `ruby -r #{v + 'rexml/rexml'} -e 'p REXML::VERSION'`.split('.').collect {|n| n.to_i} }
$:.unshift('vendor/plugins/rexml/lib') if (rexml_versions[0] <=> rexml_versions[1]) == -1

require File.join(File.dirname(__FILE__), 'boot')

require 'rails_generator/secret_key_generator'

Rails::Initializer.run do |config|

  # Secret session key
  #   The secret session key is automatically generated, and stored
  #   in a file, for reuse between server restarts. If you want to
  #   change the key, just delete the file, and it will be regenerated
  #   on the next restart. Doing so will invalitate all existing sessions.
  secret_file = File.join(RAILS_ROOT, "secret")  
  if File.exist?(secret_file)  
    secret = File.read(secret_file)  
  else  
    secret = Rails::SecretKeyGenerator.new("Instiki").generate_secret  
    File.open(secret_file, 'w', 0600) { |f| f.write(secret) }  
  end  
  config.action_controller.session = { 
    :session_key => "instiki_session",
    :secret => secret
   } 

  # Don't do file system STAT calls to check to see if the templates have changed.
  #config.action_view.cache_template_loading = true

  # Skip frameworks you're not going to use
  config.frameworks -= [ :action_web_service, :action_mailer ]

  # Use the database for sessions instead of the file system
  # (create the session table with 'rake create_sessions_table')
  #config.action_controller.session_store = :active_record_store

  # Enable page/fragment caching by setting a file-based store
  # (remember to create the caching directory and make it readable to the application)
  config.action_controller.cache_store = :file_store, "#{RAILS_ROOT}/cache"

  # Activate observers that should always be running
  config.active_record.observers = :page_observer

  # Use Active Record's schema dumper instead of SQL when creating the test database
  # (enables use of different database adapters for development and test environments)
  config.active_record.schema_format = :sql

  config.load_paths << "#{RAILS_ROOT}/vendor/plugins/sqlite3-ruby"
  File.umask(0026)
end

# Instiki-specific configuration below
require_dependency 'instiki_errors'

require 'jcode'
