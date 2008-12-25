#!/usr/bin/env ruby
#coding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class WikiWordsTest < Test::Unit::TestCase
  
  def test_utf8_characters_in_wiki_word
    assert_equal "Æåle Øen", WikiWords.separate("ÆåleØen")
    assert_equal "ÆÅØle Øen", WikiWords.separate("ÆÅØleØen")
    assert_equal "Æe ÅØle Øen", WikiWords.separate("ÆeÅØleØen")
    assert_equal "Legetøj", WikiWords.separate("Legetøj")
  end
  
  def test_multiple_leading_capital_letters
    assert_equal "CMy App", WikiWords.separate("CMyApp")
  end
end
