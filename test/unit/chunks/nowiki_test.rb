#!/bin/env ruby

require File.dirname(__FILE__) + '/../../test_helper'
require 'chunks/nowiki'
require 'chunks/match'

class NoWikiTest < Test::Unit::TestCase
  include ChunkMatch

  def test_simple_nowiki
	match(NoWiki, 'This sentence contains <nowiki>[[raw text]]</nowiki>. Do not touch!',
		:plain_text => '[[raw text]]'
	)
  end

end
