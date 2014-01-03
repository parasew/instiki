#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
require 'chunks/nowiki'
require 'nokogiri'

class NoWikiTest < Test::Unit::TestCase
  include ChunkMatch

  def ns
  # LibXML is #%$* strange. How it treats this (not namespace well-formed) input varies
  # from version to version.
    Nokogiri::XML::Document.parse('<a foo:bar=""/>').to_xml =~ /foo/ ? 'xlink:' : ''
  end

  def test_simple_nowiki
	match(NoWiki, 'This sentence contains <nowiki>[[raw text]]</nowiki>. Do not touch!',
		:plain_text => '[[raw text]]'
	)
  end

  def test_include_nowiki
	match(NoWiki, 'This sentence contains <nowiki>[[!include foo]]</nowiki>. Do not touch!',
		:plain_text => '[[!include foo]]'
	)
  end

  def test_markdown_nowiki
	match(NoWiki, 'This sentence contains <nowiki>*raw text*</nowiki>. Do not touch!',
		:plain_text => '*raw text*'
	)
  end

  def test_sanitize_nowiki
	match(NoWiki, 'This sentence contains <nowiki>[[test]]&<a href="a&b">shebang</a> <script>alert("xss!");</script> *foo*</nowiki>. Do not touch!',
		:plain_text => "[[test]]&amp;<a href=\"a&amp;b\">shebang</a> &lt;script&gt;alert(\"xss!\");&lt;/script&gt; *foo*"
	)
  end

# Here, the input is not namespace-well-formed, but the output is.
# I think that's OK.
  def test_sanitize_nowiki_ill_formed
    match(NoWiki, "<nowiki><animateColor xlink:href='#foo'/></nowiki>",
                :plain_text => "<animateColor #{ns}href=\"#foo\"/>"
    )
  end

  def test_sanitize_nowiki_ill_formed_II
    match(NoWiki, "<nowiki><animateColor xlink:href='#foo'/>\000</nowiki>",
                :plain_text => "<animateColor #{ns}href=\"#foo\"/>"
    )
  end

  def test_sanitize_nowiki_ill_formed_III
    match(NoWiki, "<nowiki><animateColor xlink:href='#foo' xmlns:xlink='http://www.w3.org/1999/xlink'/>\000</nowiki>",
                :plain_text => '<animateColor xmlns:xlink="http://www.w3.org/1999/xlink" xlink:href="#foo"/>'
    )
  end

  def test_sanitize_nowiki_bad_utf8
    match(NoWiki, "<nowiki>\357elephant &AMP; \302ivory</nowiki>".as_bytes,
                :plain_text => "".respond_to?(:force_encoding) ? "elephant &amp;AMP; ivory" : "ephant &amp;AMP; vory"
    )
  end

  def test_sanitize_empty_nowiki
    match(NoWiki, "<nowiki></nowiki>",
                :plain_text => ''
    )
  end

  def test_sanitize_blank_nowiki
    match(NoWiki, "<nowiki>\n</nowiki>",
                :plain_text => "\n"
    )
  end

end
