#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
require 'chunks/nowiki'

class NoWikiTest < Test::Unit::TestCase
  include ChunkMatch

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
		:plain_text => "[[test]]&amp;<a href='a&amp;b'>shebang</a> &lt;script&gt;alert(&quot;xss!&quot;);&lt;/script&gt; *foo*"
	)
  end

  def test_sanitize_nowiki_ill_formed
    match(NoWiki, "<nowiki><animateColor xlink:href='#foo'/></nowiki>",
                :plain_text => "&lt;animateColor xlink:href=&#39;#foo&#39;/&gt;"
    )
  end

  def test_sanitize_nowiki_ill_formed_II
    match(NoWiki, "<nowiki><animateColor xlink:href='#foo'/>\000</nowiki>",
                :plain_text => %(&lt;animateColor xlink:href=&#39;#foo&#39;/&gt;)
    )
  end

  def test_sanitize_nowiki_bad_utf8
    match(NoWiki, "<nowiki>\357elephant &AMP; \302ivory</nowiki>",
                :plain_text => "".respond_to?(:force_encoding) ? "elephant &amp;AMP; ivory" : "ephant &amp;AMP; vory"
    )
  end

end
