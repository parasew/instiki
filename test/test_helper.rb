ENV['RAILS_ENV'] = 'test'

# Expand the path to environment so that Ruby does not load it multiple times
# File.expand_path can be removed if Ruby 1.9 is in use.
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'environment'))

require 'test_help'
require 'wiki_content'
require 'url_generator'
require 'digest/sha1'

# simulates cookie session store
class FakeSessionDbMan
  def self.generate_digest(data)
    Digest::SHA1.hexdigest("secure")
  end
end

class  ActiveSupport::TestCase
  self.pre_loaded_fixtures = false
  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures = false
  self.fixture_path = Rails.root.join('test', 'fixtures', '')
end

# activate PageObserver
PageObserver.instance

class Test::Unit::TestCase
  def create_fixtures(*table_names)
    Fixtures.create_fixtures(Rails.root.join('test', 'fixtures'), table_names)
  end

  # Add more helper methods to be used by all tests here...
  def set_web_property(property, value)
    @web.update_attribute(property, value)
    @page = Page.find(@page.id)
    @wiki.webs[@web.name] = @web
  end
  
  def setup_wiki_with_30_pages
    ActiveRecord::Base.silence do
      (1..30).each do |i|
        @wiki.write_page('wiki1', "page#{i}", "Test page #{i}\ncategory: test", 
                         Time.local(1976, 10, i, 12, 00, 00), Author.new('Dema', '127.0.0.2'),
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
      assert content.chunks.last.kind_of?(chunk_type)
      assert_respond_to(content.chunks.last, a_method)
      assert_equal(expected_value, content.chunks.last.send(a_method.to_sym),
        "Wrong #{a_method} value")
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

  def page_link(mode, name, text, web_address, known_page)
    link = CGI.escape(name)
    title = web_address == 'wiki1' ? '' : " title='#{web_address}'"
    case mode
    when :export
      if known_page then %{<a class="existingWikiWord" href="#{link}.html">#{text}</a>}
      else %{<span class="newWikiWord">#{text}</span>} end
    when :publish
      if known_page then %{<a class="existingWikiWord" href="../published/#{link}"#{title}>#{text}</a>}
      else %{<span class="newWikiWord">#{text}</span>} end
    else 
      if known_page
        if web_address == 'instiki'
          %{<a class="existingWikiWord" href="../../#{web_address}/show/#{link}"#{title}>#{text}</a>}
        else
          %{<a class="existingWikiWord" href="../show/#{link}"#{title}>#{text}</a>}        
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

  def media_link(mode, name, text, web_address, known_media, media_type)
    link = CGI.escape(name)
    text = CGI.escapeHTML(CGI.unescapeHTML(text || :description))
    case mode.to_sym
    when :export
      if known_media 
        %{<#{media_type} src="#{CGI.escape(name)}" controls="controls">#{text}</#{media_type}>}
      else 
        text
      end
    when :publish
      if known_media
        %{<#{media_type} src="../file/#{link}" controls="controls">#{text}</#{media_type}>}
      else 
        %{<span class="newWikiWord">#{text}</span>} 
      end
    else 
      if known_media 
        %{<#{media_type} src="../file/#{link}" controls="controls">#{text}</#{media_type}>}
      else 
        %{<span class="newWikiWord">#{text}<a href="../file/#{link}">?</a></span>} 
      end
    end
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
