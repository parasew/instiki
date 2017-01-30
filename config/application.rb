require File.expand_path('../boot', __FILE__)

require 'rails/all'

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  Bundler.require(*Rails.groups(:assets => %w(development test)))
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end

module Instiki
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Secret session key
    #   The secret session key is automatically generated, and stored
    #   in a file, for reuse between server restarts. If you want to
    #   change the key, just delete the file, and it will be regenerated
    #   on the next restart. Doing so will invalitate all existing sessions.
    secret_file = Rails.root.join("secret")  
    if File.exist?(secret_file)  
      secret = secret_file.read  
    else  
      secret =  ActiveSupport::SecureRandom.hex(64)
      File.open(secret_file, 'w', 0600) { |f| f.write(secret) }  
    end  

    # Enable page/fragment caching by setting a file-based store
    # (remember to create the caching directory and make it readable to the application)
    config.cache_store = :file_store, "#{Rails.root}/cache"

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)

    config.autoload_paths += %W( #{config.root}/lib {config.root}/lib/chunks)
    
    # Legacy Rails 2 JS code uses Prototype, not jQuery.#

    config.action_view.javascript_expansions[:legacy] = %w(prototype.js scriptaculous.js)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    config.active_record.observers = :page_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Enable escaping HTML in JSON.
    config.active_support.escape_html_entities_in_json = true

    # Use Active Record's schema dumper instead of SQL when creating the test database
    # (enables use of different database adapters for development and test environments)
    config.active_record.schema_format = :sql

    # Enforce whitelist mode for mass assignment.
    # This will create an empty whitelist of attributes available for mass-assignment for all models
    # in your app. As such, your models will need to explicitly whitelist or blacklist accessible
    # parameters by using an attr_accessible or attr_protected declaration.
    config.active_record.whitelist_attributes = true

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    File.umask(0026)
  end
end
