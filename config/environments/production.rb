Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.action_view.cache_template_loading = true

  # Rotate the log file (25 files, 1 MB each); on Heroku, write to STDOUT.
  config.logger = ENV["HEROKU_POSTGRESQL_NAVY_URL"] \
    ? Logger.new(STDOUT)
    : Logger.new(Rails.root.join('log', "#{Rails.env}.log"), 25, 1024000)

  # URL for Tikz server (uncomment to enable Tikz rendering)
  #ENV['tikz_server'] = 'http://localhost:9292/'
end
