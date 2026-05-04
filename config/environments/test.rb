Rails.application.configure do
  config.cache_classes = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false

  # Disable CSRF for controller tests; production / dev still get Rails'
  # default protect_from_forgery via form_tag's authenticity_token field.
  config.action_controller.allow_forgery_protection = false

  config.action_mailer.delivery_method = :test if config.respond_to?(:action_mailer)

  # URL for Tikz server (Tikz tests rely on this)
  ENV['tikz_server'] = 'http://localhost:9292/'
end
