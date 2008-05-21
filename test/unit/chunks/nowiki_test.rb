#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../test_helper'
require 'chunks/nowiki'

class NoWikiTest < Test::Unit::TestCase
  include ChunkMatch

  def test_simple_nowiki
	match(NoWiki, 'This sentence contains <nowiki>[[raw text]]</nowiki>. Do not touch!',
		:plain_text => '[[raw text]]'
	)
  end

  def test_markdown_nowiki
	match(NoWiki, 'This sentence contains <nowiki>*raw text*</nowiki>. Do not touch!',
		:plain_text => '*raw text*'
	)
  end

  def test_sanitize_nowiki
	match(NoWiki, 'This sentence contains <nowiki>[[test]]&<a href="a&b">shebang</a> <script>alert("xss!");</script> *foo*</nowiki>. Do not touch!',
		:plain_text => "[[test]]&amp;<a href='a&amp;b'>shebang</a> &lt;script&gt;alert(\"xss!\");&lt;/script&gt; *foo*"
	)
  end

end
