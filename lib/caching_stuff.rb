# Strip the hostname from action-cache paths so requests at example.com,
# www.example.com, and instiki.example.com share a single cache file
# tree (instead of writing one cache file per hostname).
#
# actionpack-action_caching builds its path in ActionCachePath#initialize as
#
#   path = controller.url_for(options).split("://", 2).last
#
# which yields "host.example.com/wiki1/show/HomePage". Strip the leading
# "host[:port]/" segment so we end up with "wiki1/show/HomePage". The same
# transformation runs on the expire_action side (action_caching also goes
# through ActionCachePath there), so writes and invalidations stay aligned.
#
# This replaces the Rails-2.3-era patch that overrode fragment_cache_key —
# which hasn't been on action_caching's code path since the gem was
# extracted from core in Rails 4.

require "action_controller/caching/actions"

module Instiki
  module ActionCachePathHostStripping
    def initialize(controller, options = {}, infer_extension = true)
      super
      @path = @path.sub(%r{\A[^/]+/}, "")
    end
  end
end

ActionController::Caching::Actions::ActionCachePath.prepend(
  Instiki::ActionCachePathHostStripping
)

# Restore content negotiation after action_caching forces the Content-Type.
#
# ActionCacheFilter#around always finishes by setting
#   controller.content_type = Mime[cache_path.extension || :html]
# regardless of whether the request would otherwise have been served as
# application/xhtml+xml (per ApplicationController#set_content_type_header).
# In development this isn't visible because perform_caching=false leaves
# the around-filter uninstalled, but in production xhtml-capable browsers
# silently get text/html.
#
# Re-run set_content_type_header after the around-filter so the negotiated
# type wins. The cached body is identical between xhtml-capable and
# html-only clients (Markdown+itex2MML output is XHTML-compliant either
# way); only the response header varies by request.
module Instiki
  module ActionCacheFilterContentNegotiation
    def around(controller)
      super
      if controller.respond_to?(:set_content_type_header, true)
        controller.send(:set_content_type_header)
      end
    end
  end
end

ActionController::Caching::Actions::ActionCacheFilter.prepend(
  Instiki::ActionCacheFilterContentNegotiation
)
