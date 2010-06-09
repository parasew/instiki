#!/usr/bin/env ruby
#coding: ascii-8bit

require File.expand_path(File.join(File.dirname(__FILE__), '/../test_helper'))
require 'sanitizer'
require 'json'
require 'instiki_stringsupport'

class SanitizerTest < Test::Unit::TestCase

  include Sanitizer
  
  def setup

  end

  def do_sanitize_xhtml stream
    xhtml_sanitize(stream)
  end

  def check_sanitization(input, htmloutput, xhtmloutput, rexmloutput)
    assert_equal xhtmloutput.as_bytes, do_sanitize_xhtml(input).as_bytes
  end

  def test_sanitize_named_entities
    input = '<p>Greek &phis; &phi;, double-struck &Aopf;, numeric &#x1D538; &#8279;, uppercase &TRADE; &LT;</p>'
    output = "<p>Greek \317\225 \317\206, double-struck \360\235\224\270, numeric \360\235\224\270 \342\201\227, uppercase \342\204\242 &lt;</p>"
    output2 = "<p>Greek \317\225 \317\206, double-struck \360\235\224\270, numeric &#x1D538; &#8279;, uppercase \342\204\242 &lt;</p>"
    check_sanitization(input, output, output, output)
    assert_equal(output2, input.to_utf8.as_bytes)
  end

  def test_sanitize_malformed_utf8
    input = "<p>\357elephant &AMP; \302ivory</p>".purify
    output = "".respond_to?(:force_encoding) ? "<p>elephant &amp; ivory</p>" : "<p>ephant &amp; vory</p>"
    check_sanitization(input, output, output, output)
  end    

  Sanitizer::ALLOWED_ELEMENTS.each do |tag_name|
    define_method "test_should_allow_#{tag_name}_tag" do
      input       = "<#{tag_name} title='1'>foo <bad>bar</bad> baz</#{tag_name}>"
      htmloutput  = "<#{tag_name.downcase} title='1'>foo &lt;bad&gt;bar&lt;/bad&gt; baz</#{tag_name.downcase}>"
      xhtmloutput = "<#{tag_name} title='1'>foo &lt;bad&gt;bar&lt;/bad&gt; baz</#{tag_name}>"
      rexmloutput = xhtmloutput
      
      if VOID_ELEMENTS.include?(tag_name)
        htmloutput = "<#{tag_name} title='1'/>foo &lt;bad&gt;bar&lt;/bad&gt; baz"
        xhtmloutput = htmloutput
        htmloutput += '<br/>' if tag_name == 'br'
        rexmloutput =  "<#{tag_name} title='1' />"
      end
      check_sanitization(input, htmloutput, xhtmloutput, rexmloutput)
    end
  end

  Sanitizer::ALLOWED_ELEMENTS.each do |tag_name|
    define_method "test_should_forbid_#{tag_name.upcase}_tag" do
      input = "<#{tag_name.upcase} title='1'>foo <bad>bar</bad> baz</#{tag_name.upcase}>"
      output = "&lt;#{tag_name.upcase} title=\"1\"&gt;foo &lt;bad&gt;bar&lt;/bad&gt; baz&lt;/#{tag_name.upcase}&gt;"
      xhtmloutput = "&lt;#{tag_name.upcase} title='1'&gt;foo &lt;bad&gt;bar&lt;/bad&gt; baz&lt;/#{tag_name.upcase}&gt;"
      check_sanitization(input, output, xhtmloutput, output)
    end
  end

  Sanitizer::ALLOWED_ATTRIBUTES.each do |attribute_name|
    next if attribute_name == 'style'
    define_method "test_should_allow_#{attribute_name}_attribute" do
      input = "<p #{attribute_name}='foo'>foo <bad>bar</bad> baz</p>"
      output = "<p #{attribute_name}='foo'>foo &lt;bad&gt;bar&lt;/bad&gt; baz</p>"
      htmloutput = "<p #{attribute_name.downcase}='foo'>foo &lt;bad&gt;bar&lt;/bad&gt; baz</p>"
      check_sanitization(input, htmloutput, output, output)
    end
  end

  Sanitizer::ALLOWED_ATTRIBUTES.each do |attribute_name|
    define_method "test_should_forbid_#{attribute_name.upcase}_attribute" do
      input = "<p #{attribute_name.upcase}='display: none;'>foo <bad>bar</bad> baz</p>"
      output =  "<p>foo &lt;bad&gt;bar&lt;/bad&gt; baz</p>"
      check_sanitization(input, output, output, output)
    end
  end

  Sanitizer::ALLOWED_PROTOCOLS.each do |protocol|
    define_method "test_should_allow_#{protocol}_uris" do
      input = %(<a href="#{protocol}">foo</a>)
      output = "<a href='#{protocol}'>foo</a>"
      check_sanitization(input, output, output, output)
    end
  end

  Sanitizer::ALLOWED_PROTOCOLS.each do |protocol|
    define_method "test_should_allow_uppercase_#{protocol}_uris" do
      input = %(<a href="#{protocol.upcase}">foo</a>)
      output = "<a href='#{protocol.upcase}'>foo</a>"
      check_sanitization(input, output, output, output)
    end
  end

  Sanitizer::SVG_ALLOW_LOCAL_HREF.each do |tag_name|
    next unless Sanitizer::ALLOWED_ELEMENTS.include?(tag_name)
    define_method "test_#{tag_name}_should_allow_local_href" do
      input = %(<#{tag_name} xlink:href="#foo"/>)
      output = "<#{tag_name.downcase} xlink:href='#foo'/>"
      xhtmloutput = "<#{tag_name} xlink:href='#foo'/>"
      check_sanitization(input, output, xhtmloutput, xhtmloutput)
    end

    define_method "test_#{tag_name}_should_allow_local_href_with_newline" do
      input = %(<#{tag_name} xlink:href="\n#foo"/>)
      output = "<#{tag_name.downcase} xlink:href='\n#foo'/>"
      xhtmloutput = "<#{tag_name} xlink:href='\n#foo'/>"
      check_sanitization(input, output, xhtmloutput, xhtmloutput)
    end

    define_method "test_#{tag_name}_should_forbid_nonlocal_href" do
      input = %(<#{tag_name} xlink:href="http://bad.com/foo"/>)
      output = "<#{tag_name.downcase}/>"
      xhtmloutput = "<#{tag_name}/>"
      check_sanitization(input, output, xhtmloutput, xhtmloutput)
    end

    define_method "test_#{tag_name}_should_forbid_nonlocal_href_with_newline" do
      input = %(<#{tag_name} xlink:href="\nhttp://bad.com/foo"/>)
      output = "<#{tag_name.downcase}/>"
      xhtmloutput = "<#{tag_name}/>"
      check_sanitization(input, output, xhtmloutput, xhtmloutput)
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

    JSON::parse(open(File.expand_path(File.join(File.dirname(__FILE__), '/../sanitizer.dat'))).read).each do |test|
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
