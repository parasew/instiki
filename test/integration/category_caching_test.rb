require_relative '../test_helper'

# Regression test for action-cache key collision across :category values.
#
# actionpack-action_caching builds the cache key from
#   controller.url_for(options)
# where options is empty on the read/write side. In Rails 2.3, url_for({})
# merged with the current request's params, so /list and /list/animals had
# distinct cache keys. In Rails 7, url_for({}) does NOT inherit
# path_parameters that aren't in options — so /wiki1/list/animals and
# /wiki1/list/trees collapse onto the same cache file as /wiki1/list, and
# whichever request primed the cache wins for everyone.
#
# The fix in lib/caching_stuff.rb merges request.path_parameters into
# options before super so url_for sees the full route data.
class CategoryCachingTest < ActionDispatch::IntegrationTest
  fixtures :webs, :pages, :revisions, :system, :wiki_references

  def setup
    @cache_dir = Rails.root.join("cache")
    FileUtils.rm_rf(@cache_dir)

    @prev_perform_caching = ActionController::Base.perform_caching
    @prev_callbacks = WikiController._process_action_callbacks
    ActionController::Base.perform_caching = true
    WikiController.caches_action :list, :recently_revised,
        :if => Proc.new { |c| c.send(:do_caching?) }
  end

  def teardown
    WikiController._process_action_callbacks = @prev_callbacks
    ActionController::Base.perform_caching = @prev_perform_caching
    FileUtils.rm_rf(@cache_dir)
  end

  def test_list_with_category_does_not_collide_with_list_without_category
    get "/wiki1/list"
    assert_response :success
    body_all = response.body
    assert_match %r{>Elephant<}, body_all
    assert_match %r{>Oak<}, body_all

    get "/wiki1/list/animals"
    assert_response :success
    body_animals = response.body
    assert_match %r{>Elephant<}, body_animals,
        "category-filtered list should still show pages in that category"
    assert_no_match %r{<li id="page_7" class="page">}, body_animals,
        "Oak (in trees) should NOT appear in animals filter"

    get "/wiki1/list/trees"
    assert_response :success
    body_trees = response.body
    assert_match %r{>Oak<}, body_trees
    assert_no_match %r{<li id="page_8" class="page">}, body_trees,
        "Elephant (in animals) should NOT appear in trees filter"

    refute_equal body_all, body_animals,
        "/list and /list/animals served identical bodies — cache key collision"
    refute_equal body_animals, body_trees,
        "/list/animals and /list/trees served identical bodies — cache key collision"
  end

  def test_recently_revised_with_category_does_not_collide
    get "/wiki1/recently_revised"
    body_all = response.body
    get "/wiki1/recently_revised/animals"
    body_animals = response.body
    refute_equal body_all, body_animals,
        "recently_revised cache key must vary by :category"
  end
end
