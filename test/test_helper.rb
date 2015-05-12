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
      content.chunks.each do |c|
        assert c.kind_of?(chunk_type)
        assert_respond_to(c, a_method)
        assert_equal(expected_value, c.send(a_method.to_sym),
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
