#!/bin/env ruby -w

require File.dirname(__FILE__) + '/../test_helper'
require 'web'
require 'revision'
require 'fileutils'

class RevisionTest < Test::Unit::TestCase

  def setup
    setup_test_wiki
    @web.markup = :textile

    @page = @wiki.read_page('wiki1', 'HomePage')
    ['MyWay', 'SmartEngine', 'ThatWay'].each do |page|
      @wiki.write_page('wiki1', page, page, Time.now, 'Me')
    end

    @revision = Revision.new(@page, 1,
      'HisWay would be MyWay in kinda ThatWay in HisWay though MyWay \OverThere -- ' +
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
        '<span class="newWikiWord">Smart Engine GUI' +
        '<a href="../show/SmartEngineGUI">?</a></span></p>', 
        @revision.display_content
  end

  def test_markdown
    @web.markup = :markdown

    assert_markup_parsed_as(
        %{<h1>My Headline</h1>\n\n\n\t<p>that <span class="newWikiWord">} +
        %{Smart Engine GUI<a href="../show/SmartEngineGUI">?</a></span></p>}, 
        "My Headline\n===========\n\nthat SmartEngineGUI")

	code_block = [ 
	    'This is a code block:',
        '',
        '    def a_method(arg)',
        '    return ThatWay',
        '',
        'Nice!'
      ].join("\n")

	assert_markup_parsed_as(
	    %{<p>This is a code block:</p>\n\n\n\t<pre><code>def a_method(arg)\n} +
	    %{return ThatWay</code></pre>\n\n\n\t<p>Nice!</p>}, 
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

  def test_content_with_escaped_wikiword
    # there should be no wiki link
    assert_markup_parsed_as('<p>WikiWord</p>', '\WikiWord')
  end

  def test_content_with_pre_blocks
    assert_markup_parsed_as(
	    '<p>A <code>class SmartEngine end</code> would not mark up <pre>CodeBlocks</pre></p>', 
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

  def test_content_with_inlined_img_tag
	assert_markup_parsed_as( 
	    '<p>This <img src="http://hobix.com/sample.jpg" alt="" /> is an inline image link.</p>', 
	    'This <img src="http://hobix.com/sample.jpg" alt="" /> is an inline image link.')
	assert_markup_parsed_as( 
	    '<p>This <IMG SRC="http://hobix.com/sample.jpg" alt=""> is an inline image link.</p>', 
	    'This <IMG SRC="http://hobix.com/sample.jpg" alt=""> is an inline image link.')
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
        '<span class="newWikiWord">Smart Engine GUI</span></p>', 
        @revision.display_content_for_export
  end

  def test_double_replacing
    @revision.content = "VersionHistory\r\n\r\ncry VersionHistory"
    assert_equal '<p><span class="newWikiWord">Version History' +
        "<a href=\"../show/VersionHistory\">?</a></span></p>\n\n\n\t<p>cry " +
        '<span class="newWikiWord">Version History<a href="../show/VersionHistory">?</a>' +
        '</span></p>', 
        @revision.display_content

    @revision.clear_display_cache

    @revision.content = "f\r\nVersionHistory\r\n\r\ncry VersionHistory"
    assert_equal "<p>f\n<span class=\"newWikiWord\">Version History" +
        "<a href=\"../show/VersionHistory\">?</a></span></p>\n\n\n\t<p>cry " +
        "<span class=\"newWikiWord\">Version History<a href=\"../show/VersionHistory\">?</a>" +
        "</span></p>", 
        @revision.display_content
  end  

  def test_difficult_wiki_words
    @revision.content = "[[It's just awesome GUI!]]"
    assert_equal "<p><span class=\"newWikiWord\">It's just awesome GUI!" +
        "<a href=\"../show/It%27s+just+awesome+GUI%21\">?</a></span></p>", 
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

  def test_link_to_file
  	assert_markup_parsed_as( 
  	    '<p><span class="newWikiWord">doc.pdf<a href="../file/doc.pdf">?</a></span></p>',
	    '[[doc.pdf:file]]')
  end

  def test_link_to_pic
    FileUtils.mkdir_p "#{RAILS_ROOT}/storage/test/wiki1"
    FileUtils.rm(Dir["#{RAILS_ROOT}/storage/test/wiki1/*"])
    @wiki.file_yard(@web).upload_file('square.jpg', StringIO.new(''))
  	assert_markup_parsed_as(
  	    '<p><img alt="Square" src="../pic/square.jpg" /></p>',
	    '[[square.jpg|Square:pic]]')
  	assert_markup_parsed_as( 
  	    '<p><img alt="square.jpg" src="../pic/square.jpg" /></p>',
	    '[[square.jpg:pic]]')
  end

  def test_link_to_non_existant_pic
  	assert_markup_parsed_as(
  	    '<p><span class="newWikiWord">NonExistant<a href="../pic/NonExistant.jpg">?</a>' +
  	    '</span></p>',
        '[[NonExistant.jpg|NonExistant:pic]]')
  	assert_markup_parsed_as(
  	    '<p><span class="newWikiWord">NonExistant.jpg<a href="../pic/NonExistant.jpg">?</a>' +
  	    '</span></p>',
        '[[NonExistant.jpg:pic]]')
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
