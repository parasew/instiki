#!/bin/env ruby

require File.dirname(__FILE__) + '/../../test_helper'
require 'chunks/wiki'
require 'chunks/match'

class WikiTest < Test::Unit::TestCase
  include ChunkMatch

  def test_simple
	match(WikiChunk::Word, 'This is a WikiWord okay?', :page_name => 'WikiWord')
  end

  def test_escaped
	match(WikiChunk::Word, 'Do not link to an \EscapedWord',
		:page_name => 'EscapedWord', :escaped_text => 'EscapedWord'
	)
  end

  def test_simple_brackets
	match(WikiChunk::Link, 'This is a [[bracketted link]]',
		:page_name => 'bracketted link', :escaped_text => nil
	)
  end

  def test_complex_brackets
	match(WikiChunk::Link, 'This is a tricky link [[Sperberg-McQueen]]',
		:page_name => 'Sperberg-McQueen', :escaped_text => nil
	)
  end

  def test_textile_link
	assert_no_match(WikiChunk::Word.pattern, '"Here is a special link":SpecialLink')
  end

end
