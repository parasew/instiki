#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require 'sanitize'

class SanitizeTest < Test::Unit::TestCase

  include Sanitize

  def setup

  end

  def rexml_doc(string)
    REXML::Document.new(
      "<div xmlns='http://www.w3.org/1999/xhtml'>#{string}</div>")
  end
  
  def my_rex(string)
    sanitize_rexml(rexml_doc(string)).gsub(/\A<div xmlns="http:\/\/www.w3.org\/1999\/xhtml">(.*)<\/div>\Z/m, '\1')
  end

  def test_sanitize_named_entities
    input = '<p>Greek &phi;, double-struck &Aopf;, numeric &#x1D538; &#8279;</p>'
    output = "<p>Greek \317\225, double-struck \360\235\224\270, numeric \360\235\224\270 \342\201\227</p>"
    output2 = "<p>Greek \317\225, double-struck \360\235\224\270, numeric &#x1D538; &#8279;</p>"
    assert_equal(output, sanitize_xhtml(input))
    assert_equal(output, sanitize_html(input))
    assert_equal(output, my_rex(input))
    assert_equal(output2, input.to_utf8)
  end


end
