require_relative '../test_helper'

# Exercises Accept-header content negotiation under action caching.
#
# Regression: ActionCacheFilter#around finishes every request by setting
#   controller.content_type = Mime[cache_path.extension || :html]
# which clobbers ApplicationController#set_content_type_header. Under
# perform_caching=false (test/dev default) the around-filter is never
# installed, so set_content_type_header survives and content negotiation
# works. Under perform_caching=true (production), the override silently
# wins and xhtml-capable browsers were getting text/html.
#
# This test exercises the production path: it forces perform_caching on
# for the duration of the test so the action-cache around-filter actually
# installs.
class ContentNegotiationTest < ActionDispatch::IntegrationTest
  fixtures :webs, :pages, :revisions, :system

  XHTML_ACCEPT = "application/xhtml+xml,text/html;q=0.9,*/*;q=0.8".freeze
  HTML_ACCEPT  = "text/html,*/*;q=0.8".freeze

  def setup
    @cache_dir = Rails.root.join("cache")
    FileUtils.rm_rf(@cache_dir)

    # caches_action checks `perform_caching && cache_store` at controller
    # class-load time and skips installing the around-filter when
    # perform_caching=false (which is the test-env default). By the time
    # this test runs WikiController has long since loaded, so toggling
    # perform_caching now wouldn't retroactively install the filter.
    # Install it manually for the duration of the test, and snapshot
    # the callback chain so teardown can restore the original.
    @prev_perform_caching = ActionController::Base.perform_caching
    @prev_callbacks = WikiController._process_action_callbacks
    ActionController::Base.perform_caching = true
    WikiController.caches_action :show, :if => Proc.new { |c| c.send(:do_caching?) }

    @web = webs(:test_wiki)
    # markdownMML is one of the markdown-family markups that triggers xhtml_enabled?
    assert_equal :markdownMML, @web.markup, "test_wiki fixture must use a markdown-family markup for this test"
  end

  def teardown
    WikiController._process_action_callbacks = @prev_callbacks
    ActionController::Base.perform_caching = @prev_perform_caching
    FileUtils.rm_rf(@cache_dir)
  end

  def test_html_only_browser_gets_text_html
    get "/wiki1/show/HomePage", headers: { "Accept" => HTML_ACCEPT }
    assert_response :success
    assert_match %r{\Atext/html(;|\z)}, response.content_type.to_s,
        "html-only browser should be served text/html"
  end

  def test_xhtml_capable_browser_gets_application_xhtml_xml
    get "/wiki1/show/HomePage", headers: { "Accept" => XHTML_ACCEPT }
    assert_response :success
    assert_match %r{\Aapplication/xhtml\+xml(;|\z)}, response.content_type.to_s,
        "xhtml-capable browser should be served application/xhtml+xml"
  end

  # The bug: the first request primes the cache, the second hits the cache
  # and gets text/html because action_caching always finishes by setting
  # content_type = Mime[cache_path.extension || :html]. With the prepend
  # in lib/caching_stuff.rb that re-runs set_content_type_header, the cache
  # hit is served with the negotiated type instead.
  def test_cache_hit_preserves_negotiated_content_type
    # Prime the cache with an html-only Accept.
    get "/wiki1/show/HomePage", headers: { "Accept" => HTML_ACCEPT }
    assert_response :success
    assert_match %r{\Atext/html(;|\z)}, response.content_type.to_s

    # The cache file should now exist; the next request should hit it.
    assert cache_file_exists?, "expected action_caching to have written a cache file under #{@cache_dir}"

    # Same URL, different Accept — under the bug this returned text/html.
    get "/wiki1/show/HomePage", headers: { "Accept" => XHTML_ACCEPT }
    assert_response :success
    assert_match %r{\Aapplication/xhtml\+xml(;|\z)}, response.content_type.to_s,
        "xhtml-capable cache hit must NOT inherit the html content-type from the cached response"

    # And back the other way — html-only browser still gets text/html.
    get "/wiki1/show/HomePage", headers: { "Accept" => HTML_ACCEPT }
    assert_response :success
    assert_match %r{\Atext/html(;|\z)}, response.content_type.to_s
  end

  private

  def cache_file_exists?
    # ActiveSupport's :file_store hashes the cache key into a sharded path
    # like cache/AB2/2D0/views%2Fwiki1%2Fshow%2FHomePage, so just look for
    # any file whose name ends in "HomePage".
    Dir.glob(@cache_dir.join("**", "*HomePage*")).any? { |p| File.file?(p) }
  end
end
