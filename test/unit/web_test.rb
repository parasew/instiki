#!/bin/env ruby -w

require File.dirname(__FILE__) + '/../test_helper'
require 'wiki_service'

class WebTest < Test::Unit::TestCase
  def setup
    @web = Web.new nil, 'Instiki', 'instiki'
  end
  
  def test_wiki_word_linking
    @web.add_page(Page.new(@web, 'SecondPage', 'Yo, yo. Have you EverBeenHated', Time.now, 
        'DavidHeinemeierHansson'))
    
    assert_equal('<p>Yo, yo. Have you <span class="newWikiWord">Ever Been Hated' + 
        '<a href="../show/EverBeenHated">?</a></span></p>', 
    @web.pages["SecondPage"].display_content)
    
    @web.add_page(Page.new(@web, 'EverBeenHated', 'Yo, yo. Have you EverBeenHated', Time.now, 
        'DavidHeinemeierHansson'))
    assert_equal('<p>Yo, yo. Have you <a class="existingWikiWord" ' +
        'href="../show/EverBeenHated">Ever Been Hated</a></p>', 
    @web.pages['SecondPage'].display_content)
  end
  
  def test_pages_by_revision
    add_sample_pages
    assert_equal 'EverBeenHated', @web.select.by_revision.first.name
  end
  
  def test_pages_by_match
    add_sample_pages
    assert_equal 2, @web.select { |page| page.content =~ /me/i }.length
    assert_equal 1, @web.select { |page| page.content =~ /Who/i }.length
    assert_equal 0, @web.select { |page| page.content =~ /none/i }.length
  end
  
  def test_references
    add_sample_pages
    assert_equal 1, @web.select.pages_that_reference('EverBeenHated').length
    assert_equal 0, @web.select.pages_that_reference('EverBeenInLove').length
  end
  
  def test_delete
    add_sample_pages
    assert_equal 2, @web.pages.length
    @web.remove_pages([ @web.pages['EverBeenInLove'] ])
    assert_equal 1, @web.pages.length
  end
  
  def test_make_link
    add_sample_pages
    
    existing_page_wiki_url = 
        '<a class="existingWikiWord" href="../show/EverBeenInLove">Ever Been In Love</a>'
    existing_page_published_url = 
        '<a class="existingWikiWord" href="../published/EverBeenInLove">Ever Been In Love</a>'
    existing_page_static_url = 
        '<a class="existingWikiWord" href="EverBeenInLove.html">Ever Been In Love</a>'
    new_page_wiki_url = 
        '<span class="newWikiWord">Unknown Word<a href="../show/UnknownWord">?</a></span>'
    new_page_published_url = 
    new_page_static_url =
        '<span class="newWikiWord">Unknown Word</span>'
    
    # no options
    assert_equal existing_page_wiki_url, @web.make_link('EverBeenInLove')

    # :mode => :export
    assert_equal existing_page_static_url, @web.make_link('EverBeenInLove', nil, :mode => :export)

    # :mode => :publish
    assert_equal existing_page_published_url, 
        @web.make_link('EverBeenInLove', nil, :mode => :publish)

    # new page, no options
    assert_equal new_page_wiki_url, @web.make_link('UnknownWord')

    # new page, :mode => :export
    assert_equal new_page_static_url, @web.make_link('UnknownWord', nil, :mode => :export)

    # new page, :mode => :publish
    assert_equal new_page_published_url, @web.make_link('UnknownWord', nil, :mode => :publish)

    # Escaping special characters in the name
    assert_equal(
        '<span class="newWikiWord">Smith &amp; Wesson<a href="../show/Smith+%26+Wesson">?</a></span>', 
        @web.make_link('Smith & Wesson'))

    # optionally using text as the link text
    assert_equal(
      existing_page_published_url.sub(/>Ever Been In Love</, ">Haven't you ever been in love?<"),
      @web.make_link('EverBeenInLove', "Haven't you ever been in love?", :mode => :publish))

  end

  def test_initialize
    wiki_stub = Object.new

    web = Web.new(wiki_stub, 'Wiki2', 'wiki2', '123')

    assert_equal wiki_stub, web.wiki
    assert_equal 'Wiki2', web.name
    assert_equal 'wiki2', web.address
    assert_equal '123', web.password

    # new web should be set for maximum features enabled
    assert_equal :textile, web.markup
    assert_equal '008B26', web.color
    assert !web.safe_mode
    assert_equal {}, web.pages
    assert web.allow_uploads
    assert_equal @wiki, web.parent_wiki
    assert_nil web.additional_style
    assert !web.published
    assert !web.brackets_only
    assert !web.count_pages
    assert web.allow_uploads
  end


  private

  def add_sample_pages
    @web.add_page(Page.new(@web, 'EverBeenInLove', 'Who am I me', 
    Time.local(2004, 4, 4, 16, 50), 'DavidHeinemeierHansson'))
    @web.add_page(Page.new(@web, 'EverBeenHated', 'I am me EverBeenHated', 
    Time.local(2004, 4, 4, 16, 51), 'DavidHeinemeierHansson'))
  end
end