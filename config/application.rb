require_relative "boot"

require "rails"
# Pick the frameworks we need (skip mailer/active_storage/etc. — Instiki doesn't use them).
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
# Sprockets / asset pipeline intentionally not loaded — Instiki serves assets
# directly from public/ (no JS build).

Bundler.require(*Rails.groups)

module Instiki
  class Application < Rails::Application
    config.load_defaults 7.2

    # Restore Rails 2.3-style belongs_to: not required by default. Instiki's
    # page-revise flow builds Revision and WikiReference children on an
    # unsaved Page (so they don't have a page_id yet) and relies on autosave
    # to assign the foreign key when the Page persists. Rails 5+ default of
    # required-belongs_to fails that flow with "Page must exist".
    config.active_record.belongs_to_required_by_default = false

    # Rails 7's full has_many inversing breaks the page rendering pipeline:
    # PageRenderer#update_references calls
    #   WikiReference.where(page_id: ...).delete_all
    # then rebuilds via @revision.page.wiki_references.build(...). Under full
    # inversing, @revision.page is the same object as the caller's Page, so
    # the in-memory association proxy keeps both the stale records (now
    # orphaned in the DB) and the newly built ones — autosave then persists
    # 2x rows. Disable inversing to keep them as separate proxies, matching
    # the Rails 2/6 behavior the rendering pipeline was written for.
    config.active_record.automatic_scope_inversing = false

    # File-based fragment cache, same path Instiki has always used.
    config.cache_store = :file_store, "#{Rails.root}/cache"

    # Active Record observers (extracted from core in Rails 4; rails-observers gem).
    config.active_record.observers = :page_observer if config.respond_to?(:active_record)

    # Keep the SQL schema dump (Rails 2 style); Instiki uses raw SQL features.
    config.active_record.schema_format = :sql if config.respond_to?(:active_record)

    # lib/ is not Zeitwerk-compliant (multi-class files, acronym-collapsed
    # names, monkey-patches with no new constant), so it is not added to
    # autoload/eager_load paths. Instead, config/initializers/00_load_lib.rb
    # requires each lib/ file explicitly at boot. Zeitwerk manages app/ only.

    # Guard against catastrophically slow regexps in user content.
    Regexp.timeout = 1 if Regexp.respond_to?(:timeout=)

    File.umask(0026)
  end
end

