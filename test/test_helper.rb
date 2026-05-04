ENV['RAILS_ENV'] = 'test'

# Expand the path to environment so that Ruby does not load it multiple times
# File.expand_path can be removed if Ruby 1.9 is in use.
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'environment'))

require 'rails/test_help'
require 'rails-controller-testing'
require 'wiki_content'
require 'url_generator'
require 'digest/sha1'

# rails-controller-testing isn't loaded by Rails 6 test helpers automatically;
# install on ActionController::TestCase / ActionDispatch::IntegrationTest /
# ActionDispatch::TestResponse so assert_template, assigns, and
# template_objects come back.
ActionController::TestCase.include Rails::Controller::Testing::TestProcess
ActionController::TestCase.include Rails::Controller::Testing::TemplateAssertions
ActionController::TestCase.include Rails::Controller::Testing::Integration

# Rails-2 backward-compat shim for controller test helpers. Lets the existing
# `get :show, :web => 'wiki1', :id => 'HomePage'` and `process 'edit_web',
# 'web' => 'wiki1'` syntax work without converting every test to the modern
# `get :show, params: { web: 'wiki1', id: 'HomePage' }` form.
module Rails2TestSyntax
  # Rails 5+ controller test helpers accept these kwargs natively.
  MODERN_KWARGS = %i[params session flash format method body xhr as headers env].freeze

  def process(action, *args, **kwargs)
    Rails2TestSyntax.normalize!(args, kwargs)
    action = action.to_sym if action.is_a?(String)
    super(action, *args, **kwargs)
  end

  %i[get post put patch delete head].each do |verb|
    define_method(verb) do |action, *args, **kwargs|
      Rails2TestSyntax.normalize!(args, kwargs)
      action = action.to_sym if action.is_a?(String)
      super(action, *args, **kwargs)
    end
  end

  # If the caller passed Rails-2-style positional or keyword args, repackage
  # them into params: / session: / flash:. Rails 2's process(action, params,
  # session, flash) became process(action, params:, session:, flash:).
  def self.normalize!(args, kwargs)
    # Old positional: process(action, params_hash, session_hash, flash_hash).
    if args.first.is_a?(Hash) && !kwargs.key?(:params)
      kwargs[:params] = args.shift
      kwargs[:session] = args.shift if args.first.is_a?(Hash) && !kwargs.key?(:session)
      kwargs[:flash]   = args.shift if args.first.is_a?(Hash) && !kwargs.key?(:flash)
      return
    end
    legacy = kwargs.reject { |k, _| MODERN_KWARGS.include?(k) }
    if legacy.any?
      legacy.each_key { |k| kwargs.delete(k) }
      kwargs[:params] = (kwargs[:params] || {}).merge(legacy)
    end
  end
end

ActionController::TestCase.prepend(Rails2TestSyntax)

# More Rails-2 backward-compat — has_flash_object?, has_template_object?,
# template_objects (Rails 5+ removed these from TestResponse).
module Rails2ResponseShims
  # Rails 2 exposed flash on the response; Rails 5+ moved it to the request.
  def flash
    request.flash rescue {}
  end

  def has_flash_object?(key)
    f = flash
    !f.nil? && !f[key].nil?
  end

  # Rails-2 has_template_object?(name) checked whether the controller assigned
  # an @<name> instance variable visible to the view; .template_objects
  # returned the hash. Modern Rails replaced this with controller.view_assigns
  # (provided by rails-controller-testing as `assigns`). Stash assigns on the
  # response from the test before the assertion runs.
  attr_accessor :template_objects

  def has_template_object?(name = nil)
    objs = template_objects || {}
    name.nil? ? objs.any? : objs.key?(name.to_s)
  end
end
ActionDispatch::TestResponse.prepend(Rails2ResponseShims)

# After every controller test action, capture controller.view_assigns onto
# the response so .template_objects works.
module Rails2TemplateObjectsCapture
  %i[get post put patch delete head process].each do |verb|
    define_method(verb) do |*args, **kwargs, &blk|
      result = super(*args, **kwargs, &blk)
      if @controller && @response
        begin
          @response.template_objects = @controller.view_assigns
        rescue StandardError
          @response.template_objects = {}
        end
      end
      result
    end
  end
end
ActionController::TestCase.prepend(Rails2TemplateObjectsCapture)

# Rails 2/4 assert_tag was removed in Rails 5. Provide a minimal shim that
# handles the patterns Instiki actually uses: :tag, :attributes, :parent,
# :content. Implemented via Nokogiri so we don't pull in another gem.
module Rails2AssertTag
  # Parse as XML (the bodies under test are well-formed — atom_changes.builder
  # / atom.builder emit strict XML, and the page templates are XHTML), then
  # remove_namespaces! so CSS selectors match plain tag names regardless of
  # xmlns. Rails 2's assert_tag was namespace-unaware; the existing tests
  # assume that semantics (e.g. matching `<link>` elements inside an Atom
  # `<feed xmlns="http://www.w3.org/2005/Atom">` with bare `link[rel=...]`).
  def assert_tag(opts)
    require 'nokogiri'
    if opts[:content].is_a?(Regexp)
      assert_match opts[:content], @response.body
      return
    end
    doc = Nokogiri::XML(@response.body)
    doc.remove_namespaces!
    selector = opts[:tag].to_s
    (opts[:attributes] || {}).each do |attr, val|
      if val.is_a?(Regexp)
        assert_match val, @response.body
        return
      end
      selector += "[#{attr}=\"#{val}\"]"
    end
    full = opts[:parent] ? "#{opts[:parent][:tag]} #{selector}" : selector
    nodes = doc.css(full)
    assert nodes.any?, "Expected at least one #{full} in:\n#{@response.body[0..500]}"
  end
end
ActionController::TestCase.include(Rails2AssertTag)

# simulates cookie session store
class FakeSessionDbMan
  def self.generate_digest(data)
    Digest::SHA1.hexdigest("secure")
  end
end

class ActiveSupport::TestCase
  self.pre_loaded_fixtures = false
  self.use_transactional_tests = true
  self.use_instantiated_fixtures = false
  self.fixture_paths = [Rails.root.join('test', 'fixtures').to_s]
  # fixture_file_upload defaults to file_fixture_path (test/fixtures/files)
  # in Rails 7. Point it at our fixture root so existing
  # fixture_file_upload('rails.gif') calls keep working.
  self.file_fixture_path = Rails.root.join('test', 'fixtures').to_s

  # Page#revise writes a cache file at tmp/cache/{web}_{page}.cache and
  # cached_content reads it before falling back to the renderer. The
  # transaction rolls back DB changes between tests but file-system caches
  # persist, so a previous test's revised content leaks into the next test.
  # Wipe the cache between tests.
  setup do
    cache_dir = Rails.root.join('tmp', 'cache')
    Dir.glob(cache_dir.join('*.cache')).each { |f| File.delete(f) rescue nil }
  end
end

# activate PageObserver
PageObserver.instance

class ActiveSupport::TestCase
  def create_fixtures(*table_names)
    ActiveRecord::FixtureSet.create_fixtures(Rails.root.join('test', 'fixtures'), table_names)
  end

  # Add more helper methods to be used by all tests here...
  def set_web_property(property, value)
    @web.update_attribute(property, value)
    @page = Page.find(@page.id)
    @wiki.webs[@web.name] = @web
  end

  def setup_wiki_with_60_pages
    ActiveRecord::Base.logger.silence do
      (1..60).each do |i|
        @wiki.write_page('wiki1', "page#{i}", "Test page #{i}\ncategory: test", 
                         Time.local(1976, 10+i/31, i <= 30 ? i : i-30, 12, 00, 00), Author.new('Dema', '127.0.0.2'),
                         x_test_renderer)
      end
    end
    @web = Web.find(@web.id)
  end

  def x_test_renderer(revision = nil)
    PageRenderer.setup_url_generator(StubUrlGenerator.new)
    PageRenderer.new(revision)
  end

  def use_blank_wiki
    Revision.destroy_all
    Page.destroy_all
    Web.destroy_all
  end
end

# This module is to be included in unit tests that involve matching chunks.
# It provides a easy way to test whether a chunk matches a particular string
# and any the values of any fields that should be set after a match.
class ContentStub < String

  attr_reader :web

  include ChunkManager
  def initialize(str)
    super
    init_chunk_manager
    @web = Object.new
    class << @web
      def address
        'wiki1'
      end
    end
  end

  def url_generator
     StubUrlGenerator.new
  end
     
  def page_link(*); end
end

module ChunkMatch

  # Asserts a number of tests for the given type and text.
  def match(chunk_type, test_text, expected_chunk_state)
    if chunk_type.respond_to? :pattern
      assert_match(chunk_type.pattern, test_text)
    end

    content = ContentStub.new(test_text)
      chunk_type.apply_to(content)

    # Test if requested parts are correct.
    expected_chunk_state.each_pair do |a_method, expected_value|
      content.chunks.each do |c|
        assert c.kind_of?(chunk_type)
        assert_respond_to(c, a_method)
        assert_equal(expected_value, c.send(a_method.to_sym),
        "Wrong #{a_method} value")
      end
    end
  end

  def match_pattern(chunk_type, test_text, expected_chunk_state)
    if chunk_type.respond_to? :pattern
      assert_match(chunk_type.pattern, test_text)
    end

    content = ContentStub.new(test_text)
      chunk_type.apply_to(content)

    # Test if requested parts are correct.
    expected_chunk_state.each_pair do |a_method, expected_value|
      content.chunks.each do |c|
        assert c.kind_of?(chunk_type)
        assert_respond_to(c, a_method)
        assert_match(expected_value, c.send(a_method.to_sym),
        "Wrong #{a_method} value")
      end
    end
  end

  # Asserts that test_text doesn't match the chunk_type
  def no_match(chunk_type, test_text)
    if chunk_type.respond_to? :pattern
      assert_no_match(chunk_type.pattern, test_text)
    end
  end
end

class StubUrlGenerator < AbstractUrlGenerator

  def initialize
    super(:doesnt_need_controller)
  end

  def url_for(hash = {})
    if(hash[:action] == 'list')
      "/#{hash[:web]}/list"
    else
      '../files/pngs'
    end
  end

  def file_link(mode, name, text, web_name, known_file, description)
    link = CGI.escape(name)
    case mode
    when :export
      if known_file then %{<a class="existingWikiWord" title="#{description}" href="#{link}.html">#{text}</a>}
      else %{<span class="newWikiWord">#{text}</span>} end
    when :publish
      if known_file then %{<a class="existingWikiWord" title="#{description}" href="../published/#{link}">#{text}</a>}
      else %{<span class=\"newWikiWord\">#{text}</span>} end
    else 
      if known_file
        %{<a class=\"existingWikiWord\" title="#{description}" href=\"../file/#{link}\">#{text}</a>}
      else 
        %{<span class=\"newWikiWord\">#{text}<a href=\"../file/#{link}\">?</a></span>}
      end
    end
  end

  def page_link(mode, name, anchor_name, text, web_address, known_page)
    link = CGI.escape(name)
    title = web_address == 'wiki1' ? '' : " title='#{web_address}'"
    case mode
    when :export
      if known_page then %{<a class="existingWikiWord" href="#{link}.html#{'#'+anchor_name if anchor_name}">#{text}</a>}
      else %{<span class="newWikiWord">#{text}</span>} end
    when :publish
      if known_page then %{<a class="existingWikiWord" href="../published/#{link}#{'#'+anchor_name if anchor_name}" #{title}>#{text}</a>}
      else %{<span class="newWikiWord">#{text}</span>} end
    else
      if known_page
        if web_address == 'instiki'
          %{<a class="existingWikiWord" href="../../#{web_address}/show/#{link}#{'#'+anchor_name if anchor_name}" #{title}>#{text}</a>}
        else
          %{<a class="existingWikiWord" href="../show/#{link}#{'#'+anchor_name if anchor_name}" #{title}>#{text}</a>}        
        end
      else
        if web_address == 'instiki'
           %{<span class="newWikiWord">#{text}<a href="../../#{web_address}/show/#{link}">?</a></span>}
        else
           %{<span class="newWikiWord">#{text}<a href="../show/#{link}">?</a></span>}
        end
      end
    end
  end

  def pic_link(mode, name, text, web_name, known_pic)
    link = CGI.escape(name)
    text = CGI.escapeHTML(CGI.unescapeHTML(text || :description))
    case mode.to_sym
    when :export
      if known_pic then %{<img alt="#{text}" src="#{link}" />}
      else %{<img alt="#{text}" src="no image" />} end
    when :publish
      if known_pic then %{<img alt="#{text}" src="../file/#{link}" />}
      else %{<span class="newWikiWord">#{text}</span>} end
    else 
      if known_pic then %{<img alt="#{text}" src="../file/#{link}" />}
      else %{<span class="newWikiWord">#{text}<a href="../file/#{link}">?</a></span>} end
    end
  end
end

  def media_link(mode, namelist, text, web_address, known_media, media_type)
    if known_media
      link = %{<#{media_type} controls="controls">}
      link_end = %{\n#{text}\n</#{media_type}>}
    else
      link = %{&#x5B;upload #{media_type} files:}
      link_end = %{ #{text}&#x5D;}
    end
    text = CGI.escapeHTML(CGI.unescapeHTML(text || :description))
    namelist.each do |v|
      name = v[0]
      known = v[1]
      href = CGI.escape(name)
      case mode.to_sym
      when :export
        if known 
          link << %{\n  <source src="files/#{CGI.escape(name)}"/>}
        end
      when :publish
        if known
          link << %{\n  <source src="../file/#{href}"/>}
        end
      else 
        if known 
          link << %{\n  <source src="../file/#{href}"/>}
        else 
          link << %{ <span class="newWikiWord">#{name}<a href="#{href}">?</a></span>} 
        end
      end
    end
    link << link_end
  end

  def cdf_link(mode, name, text, web_address, known_cdf)
    href = CGI.escape(name)
    badge_path = "/images/cdf-player-white.png"
    re = /\s*(\d{1,4})\s*x\s*(\d{1,4})\s*/
    tt = re.match(text)
    if tt
      width = tt[1]
      height = tt[2]
    else
      width = '500'
      height = '300'
    end
    case mode
    when :export
      if known_cdf
        cdf_div("files/#{CGI.escape(name)}", width, height, badge_path)
      else 
        CGI.escape(name)
      end
    when :publish
      if known_cdf
        cdf_div(href, width, height, badge_path)
      else 
        %{<span class="newWikiWord">#{CGI.escape(name)}</span>} 
      end
    else 
      if known_cdf 
        cdf_div(href, width, height, badge_path)
      else 
        %{<span class="newWikiWord">#{CGI.escape(name)}<a href="#{href}">?</a></span>} 
      end
    end    
  end

  def cdf_div(s, w, h, b)
    %{<div class="cdf_object" src="#{s}" width="#{w}" height="#{h}">} +
    %{<a href="http://www.wolfram.com/cdf-player/" title="Get the free Wolfram CDF } +
    %{Player"><img src="#{b}"/></a></div>}
  end

  def youtube_link(mode, name, text)
    re = /\s*(\d{1,4})\s*x\s*(\d{1,4})\s*/
    tt = re.match(text)
    if tt
      width = tt[1]
      height = tt[2]
    else
      width = '640'
      height = '390'
    end
    %{<div class='ytplayer' data-video-id='#{CGI.escape(name.strip)}' data-video-width='#{width}' data-video-height='#{height}'></div>}
  end

module Test
  module Unit
    module Assertions
      def assert_success(bypass_body_parsing = false)
        assert_response :success
        unless bypass_body_parsing  
          assert_nothing_raised(@response.body) { REXML::Document.new(@response.body) }  
        end
      end
    end
  end
end
