# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')
require 'rails_generator/secret_key_generator'

Rails::Initializer.run do |config|

  # Secret session key
  generator = Rails::SecretKeyGenerator.new("Instiki")
  config.action_controller.session = { 
     :session_key => "instiki_session",
  #####
  ### This one generates a secret key automatically at launch.
  ###     advantage: secure, no configuration necessary
  ###  disadvantage: restart the server, and all existing
  ###                session keys become invalid.
     :secret => generator.generate_secret
  ###
  ###  Alternatively, you can set your own unchanging secret key
  ###  by editing and then uncommenting the following line, instead:
  #  : secret => "a_very_long_string_of_random_letter_and_numbers"
  #####
   } 

  # Skip frameworks you're not going to use
  config.frameworks -= [ :action_web_service, :action_mailer ]

  # Use the database for sessions instead of the file system
  # (create the session table with 'rake create_sessions_table')
  #config.action_controller.session_store = :active_record_store

  # Enable page/fragment caching by setting a file-based store
  # (remember to create the caching directory and make it readable to the application)
  config.action_controller.fragment_cache_store = :file_store, "#{RAILS_ROOT}/cache"

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
