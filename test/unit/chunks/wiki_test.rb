#!/usr/bin/env ruby
#coding: UTF-8

require Rails.root.join('test', 'test_helper')
require 'chunks/wiki'

class WikiTest < Test::Unit::TestCase

  include ChunkMatch

  def test_simple
	match(WikiChunk::Word, 'This is a WikiWord okay?', :page_name => 'WikiWord')
  end

  def test_cyrillic
	match(WikiChunk::Word, 'This is a НовойСтраницы okay?', :page_name => 'НовойСтраницы')
  end

  def test_cyrillic_lowercase
	no_match(WikiChunk::Word, 'This is a Новойстраницы?')
  end

  def test_lowercase_accented
	no_match(WikiChunk::Word, "This is a Refer\303\252ncia?")
  end

  def test_escaped
    # escape is only implemented in WikiChunk::Word 
	match(WikiChunk::Word, 'Do not link to an \EscapedWord',
		:page_name => 'EscapedWord', :escaped_text => 'EscapedWord'
	)
  end

  def test_simple_brackets
    match(WikiChunk::Link, 'This is a [[bracketted link]]', :page_name => 'bracketted link')
  end

  def test_single_letter_brackets
    match(WikiChunk::Link, 'This is a [[x]]', :page_name => 'x')
  end

  def test_void_brackets
    # double brackets woith only spaces inside are not a WikiLink
    no_match(WikiChunk::Link, "This [[ ]] are [[]] no [[ \t ]] links")
  end

  def test_brackets_strip_spaces
    match(WikiChunk::Link, 
        "This is a [[Sperberg-McQueen \t ]] link with trailing spaces to strip", 
        :page_name => 'Sperberg-McQueen')
    match(WikiChunk::Link, 
        "This is a [[ \t Sperberg-McQueen]] link with leading spaces to strip", 
        :page_name => 'Sperberg-McQueen')
    match(WikiChunk::Link, 
        'This is a [[ Sperberg-McQueen  ]] link with spaces around it to strip', 
        :page_name => 'Sperberg-McQueen')
    match(WikiChunk::Link, 
        'This is a [[  Sperberg  McQueen ]] link with spaces inside and around it', 
        :page_name => 'Sperberg McQueen')
  end

  def test_complex_brackets
	match(WikiChunk::Link, 'This is a tricky link [[Sperberg-McQueen]]', 
	      :page_name => 'Sperberg-McQueen')
  end
  
  def test_interweb_links
	match(WikiChunk::Link, 'This is a tricky link [[Froogle:Sperberg-McQueen]]', 
	      {:page_name => 'Sperberg-McQueen', :web_name => 'Froogle'})
  end
  
  def test_void_include
    # double brackets with only spaces inside are not a WikiInclude
    no_match(Include, "This [[!include ]] are [[!include]] no [[!include \t ]] links")
  end

  def test_include_strip_spaces
    content = "This is a [[!include Sperberg-McQueen \t ]] link with trailing spaces to strip. " +
              "This is a [[!include \t Gross-Mende]] link with leading spaces to strip." +
              "This is a [[!include Milo Miles  ]] link with spaces around it to strip"
    recognized_includes = content.scan(Include.pattern).collect { |m| m[0] }
    assert_equal ['Sperberg-McQueen', 'Gross-Mende', 'Milo Miles'], recognized_includes
  end

  def test_include_chunk_pattern
    content = 'This is a [[!include pagename]] and [[!include WikiWord]] and [[!include x]]but [[blah]]'
    recognized_includes = content.scan(Include.pattern).collect { |m| m[0] }
    assert_equal %w(pagename WikiWord x), recognized_includes
  end

  def test_redirects_chunk_pattern
    content = 'This is a [[!redirects pagename]] and [[!redirects WikiWord]] and' +
      ' [[!redirects x]] and [[!redirects page name]] but [[blah]]'
    recognized_redirects = content.scan(Redirect.pattern).collect { |m| m[0] }
    assert_equal %w(pagename WikiWord x page\ name), recognized_redirects
  end

  def test_textile_link
    textile_link = ContentStub.new('"Here is a special link":SpecialLink')
    WikiChunk::Word.apply_to(textile_link)
    assert_equal '"Here is a special link":SpecialLink', textile_link
    assert textile_link.chunks.empty?
  end

  def test_file_types
    # only link
    assert_link_parsed_as 'only text', 'only text', :show, '[[only text]]'
    # link and text
    assert_link_parsed_as 'page name', 'link text', :show, '[[page name|link text]]'
    # link and type (file)
    assert_link_parsed_as 'foo.tar.gz', 'foo.tar.gz', :file, '[[foo.tar.gz:file]]'
    # link and type (pic)
    assert_link_parsed_as 'foo.tar.gz', 'foo.tar.gz', :pic, '[[foo.tar.gz:pic]]'
    # link, text and type
    assert_link_parsed_as 'foo.tar.gz', 'FooTar', :file, '[[foo.tar.gz|FooTar:file]]'

    # NEGATIVE TEST CASES

    # empty page name
    assert_link_parsed_as '|link text?', '|link text?', :file, '[[|link text?:file]]'
    # empty link text
    assert_link_parsed_as 'page name?|', 'page name?|', :file, '[[page name?|:file]]'
    # empty link type
    assert_link_parsed_as 'page name', 'link?:', :show, '[[page name|link?:]]'
    # unknown link type
    assert_link_parsed_as 'create_system', 'create_system', :show, 
        '[[page name:create_system]]'
  end

  def assert_link_parsed_as(expected_page_name, expected_link_text, expected_link_type, link)
    link_to_file = ContentStub.new(link)
    WikiChunk::Link.apply_to(link_to_file)
    chunk = link_to_file.chunks.last
    assert chunk
    assert_equal expected_page_name, chunk.page_name
    assert_equal expected_link_text, chunk.link_text
    assert_equal expected_link_type, chunk.link_type
  end
  
end
