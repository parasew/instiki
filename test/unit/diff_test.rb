#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require 'diff'

class DiffTest < Test::Unit::TestCase

  include HTMLDiff

  def setup
    @builder = DiffBuilder.new('old', 'new')
  end

  def test_start_of_tag
    assert @builder.start_of_tag?('<')
    assert(!@builder.start_of_tag?('>'))
    assert(!@builder.start_of_tag?('a'))
  end

  def test_end_of_tag
    assert @builder.end_of_tag?('>')
    assert(!@builder.end_of_tag?('<'))
    assert(!@builder.end_of_tag?('a'))
  end

  def test_whitespace
    assert @builder.whitespace?(" ")
    assert @builder.whitespace?("\n")
    assert @builder.whitespace?("\r")
    assert(!@builder.whitespace?("a"))
  end

  def test_convert_html_to_list_of_words_simple
    assert_equal(
        ['the', ' ', 'original', ' ', 'text'],
        @builder.convert_html_to_list_of_words('the original text'))
  end

  def test_convert_html_to_list_of_words_should_separate_endlines
    assert_equal(
        ['a', "\n", 'b', "\r", 'c'],
        @builder.convert_html_to_list_of_words("a\nb\rc"))
  end

  def test_convert_html_to_list_of_words_should_not_compress_whitespace
    assert_equal(
        ['a', ' ', 'b', '  ', 'c', "\r \n ", 'd'],
        @builder.convert_html_to_list_of_words("a b  c\r \n d"))
  end

  def test_convert_html_to_list_of_words_should_handle_tags_well
    assert_equal(
        ['<p>', 'foo', ' ', 'bar', '</p>'],
        @builder.convert_html_to_list_of_words("<p>foo bar</p>"))
  end
  
  def test_convert_html_to_list_of_words_interesting
    assert_equal(
        ['<p>', 'this', ' ', 'is', '</p>', "\r\n", '<p>', 'the', ' ', 'new', ' ', 'string', 
         '</p>', "\r\n", '<p>', 'around', ' ', 'the', ' ', 'world', '</p>'],
        @builder.convert_html_to_list_of_words(
            "<p>this is</p>\r\n<p>the new string</p>\r\n<p>around the world</p>"))
  end

  def test_html_diff_simple
    a = 'this was the original string'
    b = 'this is the new string'
    assert_equal('this <del class="diffmod">was</del><ins class="diffmod">is</ins> the ' +
           '<del class="diffmod">original</del><ins class="diffmod">new</ins> string',
           diff(a, b))
  end

  def test_html_diff_with_multiple_paragraphs
    a = "<p>this was the original string</p>"
    b = "<p>this is</p>\r\n<p> the new string</p>\r\n<p>around the world</p>"

    # Some of this expected result is accidental to implementation. 
    # At least it's well-formed and more or less correct.
    assert_equal(
        "<p>this <del class=\"diffmod\">was</del><ins class=\"diffmod\">is</ins></p>"+
        "<ins class=\"diffmod\">\r\n</ins><p> the " +
        "<del class=\"diffmod\">original</del><ins class=\"diffmod\">new</ins>" +
        " string</p><ins class=\"diffins\">\r\n</ins>" +
        "<p><ins class=\"diffins\">around the world</ins></p>",
        diff(a, b))
  end

  # FIXME this test fails (ticket #67, http://dev.instiki.org/ticket/67)
  def test_html_diff_preserves_endlines_in_pre
    a = "<pre>\na\nb\nc\n</pre>"
    b = "<pre>\n</pre>"
    assert_equal(
        "<pre>\n<del class=\"diffdel\">a\nb\nc\n</del></pre>",
        diff(a, b))
  end
  
  def test_html_diff_with_tags
    a = ""
    b = "<div>foo</div>"
    assert_equal '<div><ins class="diffins">foo</ins></div>', diff(a, b)
  end
  
  def test_diff_for_tag_change
    a = "<a>x</a>"
    b = "<b>x</b>"
    # FIXME sad, but true - this case produces an invalid XML. If handle this you can, strong your foo is.
    assert_equal '<a><b>x</a></b>', diff(a, b)
  end

end
