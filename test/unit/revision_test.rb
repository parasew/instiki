#!/bin/env ruby -w

require File.dirname(__FILE__) + '/../test_helper'
require 'web'
require 'revision'

class WebStub < Web
  def initialize(); end 
  attr_accessor :markup
  def pages() PagesStub.new end
  def safe_mode() false end
end
class PagesStub
  def [](wiki_word) %w( MyWay ThatWay SmartEngine ).include?(wiki_word) end
end
class PageStub
  attr_accessor :web, :revisions
  def name() 'page' end
end

class RevisionTest < Test::Unit::TestCase

  def setup
    @web  = WebStub.new
    @web.markup = :textile

    @page = PageStub.new
    @page.web = @web

    @revision = Revision.new(@page, 1,
      'HisWay would be MyWay in kinda ThatWay in HisWay though MyWay \\OverThere -- ' +
          'see SmartEngine in that SmartEngineGUI', 
      Time.local(2004, 4, 4, 16, 50), 'DavidHeinemeierHansson')
  end

  def test_wiki_words
    assert_equal %w( HisWay MyWay SmartEngine SmartEngineGUI ThatWay ), @revision.wiki_words.sort
  end
  
  def test_existing_pages
    assert_equal %w( MyWay SmartEngine ThatWay ), @revision.existing_pages.sort
  end
  
  def test_unexisting_pages
    assert_equal %w( HisWay SmartEngineGUI ), @revision.unexisting_pages.sort
  end
  
  def test_content_with_wiki_links
    assert_equal '<p><span class="newWikiWord">His Way<a href="../show/HisWay">?</a></span> ' +
        'would be <a class="existingWikiWord" href="../show/MyWay">My Way</a> in kinda ' +
        '<a class="existingWikiWord" href="../show/ThatWay">That Way</a> in ' +
        '<span class="newWikiWord">His Way<a href="../show/HisWay">?</a></span> ' +
        'though <a class="existingWikiWord" href="../show/MyWay">My Way</a> OverThere&#8212;see ' +
        '<a class="existingWikiWord" href="../show/SmartEngine">Smart Engine</a> in that ' +
        '<span class="newWikiWord">Smart Engine <span class="caps">GUI</span>' +
        '<a href="../show/SmartEngineGUI">?</a></span></p>', 
        @revision.display_content
  end

  def test_bluecloth
    @web.markup = :markdown

    assert_markup_parsed_as(
        %{<h1>My Headline</h1>\n\n<p>that <span class="newWikiWord">} +
        %{Smart Engine GUI<a href="../show/SmartEngineGUI">?</a></span></p>}, 
        "My Headline\n===========\n\n that SmartEngineGUI")

	code_block = [ 
	    'This is a code block:',
        '',
        '    def a_method(arg)',
        '    return ThatWay',
        '',
        'Nice!'
      ].join("\n")

	assert_markup_parsed_as(
	    %{<p>This is a code block:</p>\n\n<pre><code>def a_method(arg)\n} +
	    %{return ThatWay\n</code></pre>\n\n<p>Nice!</p>}, 
	    code_block)
  end

  def test_rdoc
    @web.markup = :rdoc

    @revision = Revision.new(@page, 1, '+hello+ that SmartEngineGUI', 
        Time.local(2004, 4, 4, 16, 50), 'DavidHeinemeierHansson')

    assert_equal "<tt>hello</tt> that <span class=\"newWikiWord\">Smart Engine GUI" +
        "<a href=\"../show/SmartEngineGUI\">?</a></span>\n\n", @revision.display_content
  end
  
  def test_content_with_auto_links
    assert_markup_parsed_as(
        '<p><a href="http://www.loudthinking.com/">http://www.loudthinking.com/</a> ' +
        'points to <a class="existingWikiWord" href="../show/ThatWay">That Way</a> from ' +
        '<a href="mailto:david@loudthinking.com">david@loudthinking.com</a></p>', 
        'http://www.loudthinking.com/ points to ThatWay from david@loudthinking.com')

  end  

  def test_content_with_aliased_links
    assert_markup_parsed_as(
        '<p>Would a <a class="existingWikiWord" href="../show/SmartEngine">clever motor' +
	    '</a> go by any other name?</p>',
        'Would a [[SmartEngine|clever motor]] go by any other name?')
  end

  def test_content_with_wikiword_in_em
    assert_markup_parsed_as(
        '<p><em>should we go <a class="existingWikiWord" href="../show/ThatWay">' +
	    'That Way</a> or <span class="newWikiWord">This Way<a href="../show/ThisWay">?</a>' +
	    '</span> </em></p>', 
        '_should we go ThatWay or ThisWay _')
  end

  def test_content_with_wikiword_in_tag
    assert_markup_parsed_as(
        '<p>That is some <em style="WikiWord">Stylish Emphasis</em></p>', 
	    'That is some <em style="WikiWord">Stylish Emphasis</em>')
  end

  def test_content_with_pre_blocks
    assert_markup_parsed_as(
	    'A <code>class SmartEngine end</code> would not mark up <pre>CodeBlocks</pre>', 
	    'A <code>class SmartEngine end</code> would not mark up <pre>CodeBlocks</pre>')
  end

  def test_content_with_autolink_in_parentheses
    assert_markup_parsed_as(
        '<p>The <span class="caps">W3C</span> body (<a href="http://www.w3c.org">' +
	    'http://www.w3c.org</a>) sets web standards</p>', 
	    'The W3C body (http://www.w3c.org) sets web standards')
  end

  def test_content_with_link_in_parentheses
    assert_markup_parsed_as(
        '<p>(<a href="http://wiki.org/wiki.cgi?WhatIsWiki">What is a wiki?</a>)</p>',
        '("What is a wiki?":http://wiki.org/wiki.cgi?WhatIsWiki)')
  end

  def test_content_with_image_link
	assert_markup_parsed_as( 
	    '<p>This <img src="http://hobix.com/sample.jpg" alt="" /> is a Textile image link.</p>', 
	    'This !http://hobix.com/sample.jpg! is a Textile image link.')
  end

  def test_content_with_nowiki_text
	assert_markup_parsed_as( 
	    '<p>Do not mark up [[this text]] or http://www.thislink.com.</p>', 
	    'Do not mark up <nowiki>[[this text]]</nowiki> ' +
	    'or <nowiki>http://www.thislink.com</nowiki>.')
  end

  def test_content_with_bracketted_wiki_word
	@web.brackets_only = true
	assert_markup_parsed_as( 
        '<p>This is a WikiWord and a tricky name <span class="newWikiWord">' +
	    'Sperberg-McQueen<a href="../show/Sperberg-McQueen">?</a></span>.</p>', 
	    'This is a WikiWord and a tricky name [[Sperberg-McQueen]].')
  end

  def test_content_for_export
    assert_equal '<p><span class="newWikiWord">His Way</span> would be ' +
        '<a class="existingWikiWord" href="MyWay.html">My Way</a> in kinda ' +
        '<a class="existingWikiWord" href="ThatWay.html">That Way</a> in ' +
        '<span class="newWikiWord">His Way</span> though ' +
        '<a class="existingWikiWord" href="MyWay.html">My Way</a> OverThere&#8212;see ' +
        '<a class="existingWikiWord" href="SmartEngine.html">Smart Engine</a> in that ' +
        '<span class="newWikiWord">Smart Engine <span class="caps">GUI</span></span></p>', 
        @revision.display_content_for_export
  end

  def test_double_replacing
    @revision.content = "VersionHistory\r\n\r\ncry VersionHistory"
    assert_equal '<p><span class="newWikiWord">Version History' +
        "<a href=\"../show/VersionHistory\">?</a></span></p>\n\n\t<p>cry " +
        '<span class="newWikiWord">Version History<a href="../show/VersionHistory">?</a>' +
        '</span></p>', 
        @revision.display_content

    @revision.clear_display_cache

    @revision.content = "f\r\nVersionHistory\r\n\r\ncry VersionHistory"
    assert_equal "<p>f<br />\n<span class=\"newWikiWord\">Version History" +
        "<a href=\"../show/VersionHistory\">?</a></span></p>\n\n\t<p>cry " +
        "<span class=\"newWikiWord\">Version History<a href=\"../show/VersionHistory\">?</a>" +
        "</span></p>", 
        @revision.display_content
  end  

  def test_difficult_wiki_words
    @revision.content = "[[It's just awesome GUI!]]"
    assert_equal "<p><span class=\"newWikiWord\">It&#8217;s just awesome <span class=\"caps\">GUI" +
        "</span>!<a href=\"../show/It%27s+just+awesome+GUI%21\">?</a></span></p>", 
        @revision.display_content
  end
  
  def test_revisions_diff

    @page.revisions = [
        Revision.new(@page, 0, 'What a blue and lovely morning', 
            Time.local(2004, 4, 4, 16, 50), 'DavidHeinemeierHansson'),
        Revision.new(@page, 1, 'What a red and lovely morning today', 
            Time.local(2004, 4, 4, 16, 50), 'DavidHeinemeierHansson')
      ]

    assert_equal "<p>What a <del class=\"diffmod\">blue </del><ins class=\"diffmod\">red " +
        "</ins>and lovely <del class=\"diffmod\">morning</del><ins class=\"diffmod\">morning " +
        "today</ins></p>", @page.revisions.last.display_diff
  end

  # TODO Remove the leading underscores from this test when upgrading to RedCloth 3.0.1; 
  # also add a test for the "Unhappy Face" problem (another interesting RedCloth bug)
  def __test_list_with_tildas
    list_with_tildas = <<-EOL
      * "a":~b
      * c~ d
    EOL

    assert_markup_parsed_as(
        "<li><a href=\"~b\">a</a></li>\n" +
        "<li>c~ d</li>\n",
        list_with_tildas)
  end



  def assert_markup_parsed_as(expected_output, input)
    revision = Revision.new(@page, 1, input, Time.local(2004, 4, 4, 16, 50), 'AnAuthor')
    assert_equal expected_output, revision.display_content, 'Textile output not as expected'
  end

end
