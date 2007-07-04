#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__), 'preamble')

require 'html5/html5parser'
require 'html5/liberalxmlparser'
require 'html5/treewalkers'
require 'html5/serializer'
require 'html5/sanitizer'

class SanitizeTest < Test::Unit::TestCase
  include HTML5

  def sanitize_xhtml stream
    XHTMLParser.parseFragment(stream, {:tokenizer => HTMLSanitizer, :encoding => 'utf-8'}).to_s
  end

  def sanitize_html stream
    HTMLParser.parseFragment(stream, {:tokenizer => HTMLSanitizer, :encoding => 'utf-8'}).to_s
  end

  def sanitize_rexml stream
    require 'rexml/document'
    doc = REXML::Document.new("<div xmlns='http://www.w3.org/1999/xhtml'>#{stream}</div>")
    tokens = TreeWalkers.getTreeWalker('rexml').new(doc)
    HTMLSerializer.serialize(tokens, {:encoding=>'utf-8',
      :quote_attr_values => true,
      :quote_char => "'",
      :minimize_boolean_attributes => false,
      :use_trailing_solidus => true,
      :omit_optional_tags => false,
      :inject_meta_charset => false,
      :sanitize => true}).gsub(/\A<div xmlns='http:\/\/www.w3.org\/1999\/xhtml'>(.*)<\/div>\Z/m, '\1')
  rescue REXML::ParseException
    return "Ill-formed XHTML!"
  end

  def check_sanitization(input, htmloutput, xhtmloutput, rexmloutput)
    assert_equal htmloutput, sanitize_html(input)
    assert_equal xhtmloutput, sanitize_xhtml(input)
    assert_equal rexmloutput, sanitize_rexml(input)
  end

  HTMLSanitizer::ALLOWED_ELEMENTS.each do |tag_name|
    define_method "test_should_allow_#{tag_name}_tag" do
      input = "<#{tag_name} title='1'>foo <bad>bar</bad> baz</#{tag_name}>"
      htmloutput = "<#{tag_name.downcase} title='1'>foo &lt;bad&gt;bar&lt;/bad&gt; baz</#{tag_name.downcase}>"
      xhtmloutput = "<#{tag_name} title='1'>foo &lt;bad&gt;bar&lt;/bad&gt; baz</#{tag_name}>"
      rexmloutput = xhtmloutput

      if %w[caption colgroup optgroup option tbody td tfoot th thead tr].include?(tag_name)
        htmloutput = "foo &lt;bad&gt;bar&lt;/bad&gt; baz"
        xhtmloutput = htmloutput
      elsif tag_name == 'col'
        htmloutput = "foo &lt;bad&gt;bar&lt;/bad&gt; baz"
        xhtmloutput = htmloutput
        rexmloutput = "<col title='1' />"
      elsif tag_name == 'table'
        htmloutput = "foo &lt;bad&gt;bar&lt;/bad&gt;baz<table title='1'> </table>"
        xhtmloutput = htmloutput
      elsif tag_name == 'image'
        htmloutput = "<img title='1'/>foo &lt;bad&gt;bar&lt;/bad&gt; baz"
        xhtmloutput = htmloutput
        rexmloutput = "<image title='1'>foo &lt;bad&gt;bar&lt;/bad&gt; baz</image>"
      elsif VOID_ELEMENTS.include?(tag_name)
        htmloutput = "<#{tag_name} title='1'/>foo &lt;bad&gt;bar&lt;/bad&gt; baz"
        xhtmloutput = htmloutput
        htmloutput += '<br/>' if tag_name == 'br'
        rexmloutput =  "<#{tag_name} title='1' />"
      end
      check_sanitization(input, htmloutput, xhtmloutput, rexmloutput)
    end
  end

  HTMLSanitizer::ALLOWED_ELEMENTS.each do |tag_name|
    define_method "test_should_forbid_#{tag_name.upcase}_tag" do
      input = "<#{tag_name.upcase} title='1'>foo <bad>bar</bad> baz</#{tag_name.upcase}>"
      output = "&lt;#{tag_name.upcase} title=\"1\"&gt;foo &lt;bad&gt;bar&lt;/bad&gt; baz&lt;/#{tag_name.upcase}&gt;"
      check_sanitization(input, output, output, output)
    end
  end

  HTMLSanitizer::ALLOWED_ATTRIBUTES.each do |attribute_name|
    next if attribute_name == 'style'
    define_method "test_should_allow_#{attribute_name}_attribute" do
      input = "<p #{attribute_name}='foo'>foo <bad>bar</bad> baz</p>"
      output = "<p #{attribute_name}='foo'>foo &lt;bad&gt;bar&lt;/bad&gt; baz</p>"
      htmloutput = "<p #{attribute_name.downcase}='foo'>foo &lt;bad&gt;bar&lt;/bad&gt; baz</p>"
      check_sanitization(input, htmloutput, output, output)
    end
  end

  HTMLSanitizer::ALLOWED_ATTRIBUTES.each do |attribute_name|
    define_method "test_should_forbid_#{attribute_name.upcase}_attribute" do
      input = "<p #{attribute_name.upcase}='display: none;'>foo <bad>bar</bad> baz</p>"
      output =  "<p>foo &lt;bad&gt;bar&lt;/bad&gt; baz</p>"
      check_sanitization(input, output, output, output)
    end
  end

  HTMLSanitizer::ALLOWED_PROTOCOLS.each do |protocol|
    define_method "test_should_allow_#{protocol}_uris" do
      input = %(<a href="#{protocol}">foo</a>)
      output = "<a href='#{protocol}'>foo</a>"
      check_sanitization(input, output, output, output)
    end
  end

  HTMLSanitizer::ALLOWED_PROTOCOLS.each do |protocol|
    define_method "test_should_allow_uppercase_#{protocol}_uris" do
      input = %(<a href="#{protocol.upcase}">foo</a>)
      output = "<a href='#{protocol.upcase}'>foo</a>"
      check_sanitization(input, output, output, output)
    end
  end

  def test_should_handle_astral_plane_characters
    input = "<p>&#x1d4b5; &#x1d538;</p>"
    output = "<p>\360\235\222\265 \360\235\224\270</p>"
    check_sanitization(input, output, output, output)

    input = "<p><tspan>\360\235\224\270</tspan> a</p>"
    output = "<p><tspan>\360\235\224\270</tspan> a</p>"
    check_sanitization(input, output, output, output)
  end

# This affects only NS4. Is it worth fixing?
#  def test_javascript_includes
#    input = %(<div size="&{alert('XSS')}">foo</div>)
#    output = "<div>foo</div>"    
#    check_sanitization(input, output, output, output)
#  end

  html5_test_files('sanitizer').each do |filename|
    JSON::parse(open(filename).read).each do |test|
      define_method "test_#{test['name']}" do
        check_sanitization(
          test['input'],
          test['output'],
          test['xhtml'] || test['output'],
          test['rexml'] || test['output']
        )
      end
    end
  end
end
