# Two patches to actionpack-action_caching, both for Rails 7+ behavior:
#
# 1. Strip the hostname from cache paths so requests at example.com,
#    www.example.com, and instiki.example.com share a single cache file
#    tree (instead of one per hostname). action_caching builds its path as
#       path = controller.url_for(options).split("://", 2).last
#    yielding "host.example.com/wiki1/show/HomePage"; we strip the leading
#    "host[:port]/" segment.
#
# 2. Preserve optional path parameters in the cache key. action_caching
#    calls controller.url_for(options) with options effectively empty on
#    the read/write side. In Rails 2.3, url_for({}) merged with the
#    current request's params, so /list and /list/animals had distinct
#    cache keys. In Rails 7, url_for({}) ignores path_parameters that
#    aren't in options — so /wiki1/list/animals and /wiki1/list/trees
#    collapse onto the same cache file as /wiki1/list, and the first
#    response served wins for everyone. Merge path_parameters into
#    options before super so url_for sees the full route data.
#
# The expire side (infer_extension=false) is invoked with explicit options
# from sweepers and expire_action calls — those already include :category
# etc. when needed — so we leave it alone.

require "action_controller/caching/actions"

module Instiki
  module ActionCachePathHostStripping
    def initialize(controller, options = {}, infer_extension = true)
      if infer_extension && options.is_a?(Hash)
        options = controller.request.path_parameters.merge(options)
      end
      super(controller, options, infer_extension)
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
