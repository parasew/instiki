Rails.application.configure do
  config.cache_classes = false
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false

  config.action_mailer.raise_delivery_errors = false if config.respond_to?(:action_mailer)

  # URL for Tikz server (uncomment to enable Tikz rendering)
  ENV['tikz_server'] = 'http://localhost:9292/'
end
