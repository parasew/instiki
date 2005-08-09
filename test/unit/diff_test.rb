#!/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require 'diff'

include Diff

class DiffTest < Test::Unit::TestCase
  def test_init
    assert_nothing_raised {
      s = SequenceMatcher.new('private Thread currentThread;',
            'private volatile Thread currentThread;') { |x| x == ' ' }
    }
  end
  
  def test_matching_blocks
    s = SequenceMatcher.new 'abxcd', 'abcd'
    assert_equal [[0, 0, 2], [3, 2, 2], [5, 4, 0]], s.get_matching_blocks
  end
  
  def test_ratio
    s = SequenceMatcher.new 'abcd', 'bcde'
    assert_equal 0.75, s.ratio, 0.001
    assert_equal 0.75, s.quick_ratio, 0.001
    assert_equal 1.0, s.real_quick_ratio, 0.001
  end
  
  def test_longest_match
    s = SequenceMatcher.new(' abcd', 'abcd abcd')
    assert_equal [0, 4, 5], s.find_longest_match(0, 5, 0, 9)
  end
  
  def test_opcodes
    s = SequenceMatcher.new('qabxcd', 'abycdf')
    assert_equal( 
      [
        [:delete, 0, 1, 0, 0],
        [:equal, 1, 3, 0, 2],
        [:replace, 3, 4, 2, 3],
        [:equal, 4, 6, 3, 5],
        [:insert, 6, 6, 5, 6]
      ],
      s.get_opcodes)
  end


  def test_count_leading
    assert_equal 3, Diff.count_leading('   abc', ' ')
  end

  def test_html2list
    a = "here is the original text"
    assert_equal(
        ['here ', 'is ', 'the ', 'original ', 'text'],
        HTMLDiff.html2list(a))
  end

  def test_html_diff
    a = 'this was the original string'
    b = 'this is the super string'
    assert_equal('this <del class="diffmod">was </del>' + 
           '<ins class="diffmod">is </ins>the ' +
           '<del class="diffmod">original </del>' + 
           '<ins class="diffmod">super </ins>string',
           HTMLDiff.diff(a, b))
  end
  
  def test_html_diff_with_multiple_paragraphs
    a = "<p>this was the original string</p>"
    b = "<p>this is</p>\r\n<p>the super string</p>\r\n<p>around the world</p>"

    assert_equal(
      "<p>this <del class=\"diffmod\">was </del>" + 
      "<ins class=\"diffmod\">is</ins></p>\r\n<p>the " +
      "<del class=\"diffmod\">original </del>" + 
      "<ins class=\"diffmod\">super </ins>string</p>\r\n" +
      "<p><ins class=\"diffins\">around the world</ins></p>",
      HTMLDiff.diff(a, b)
    )
  end
  
  # FIXME this test fails (ticket #67, http://dev.instiki.org/ticket/67)
  def test_html_diff_preserves_endlines_in_pre
    a = "<pre>\na\nb\nc\n</pre>"
    b = ''

    assert_equal(
        "<pre>\n<del class=\"diffdel\">a\nb\nc\n</del></pre>",
        HTMLDiff.diff(a, b))
  end
  
end
