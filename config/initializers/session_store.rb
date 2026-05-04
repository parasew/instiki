Rails.application.config.session_store :cookie_store,
  key: "instiki_session",
  same_site: :lax
