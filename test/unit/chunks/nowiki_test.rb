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

  def test_sanitized_nowiki
       match(NoWiki, 'This sentence contains <nowiki><span>a b</span> <script>alert("XSS!");</script></nowiki>. Do not touch!',
               :plain_text => '<span>a b</span> &lt;script>alert("XSS!");&lt;/script>'
       )
  end

end
