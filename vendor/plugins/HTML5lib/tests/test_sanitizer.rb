#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__), 'preamble')

require 'html5lib/html5parser'
require 'html5lib/liberalxmlparser'
require 'html5lib/treewalkers'
require 'html5lib/serializer'
require 'html5lib/sanitizer'

class SanitizeTest < Test::Unit::TestCase
  include HTML5lib

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
      :sanitize => true}).gsub(/^<div xmlns='http:\/\/www.w3.org\/1999\/xhtml'>(.*)<\/div>$/, '\1')
    rescue
      return "Ill-formed XHTML!"
  end

  def check_sanitization(input, htmloutput, xhtmloutput, rexmloutput)
      assert_equal htmloutput, sanitize_html(input)
      assert_equal xhtmloutput, sanitize_xhtml(input)
      assert_equal rexmloutput, sanitize_rexml(input)
  end

  HTMLSanitizer::ALLOWED_ELEMENTS.each do |tag_name|
    next if %w[caption col colgroup optgroup option table tbody td tfoot th thead tr].include?(tag_name) ### TODO
    define_method "test_should_allow_#{tag_name}_tag" do
      input = "<#{tag_name} title='1'>foo <bad>bar</bad> baz</#{tag_name}>"
      htmloutput = "<#{tag_name.downcase} title='1'>foo &lt;bad&gt;bar&lt;/bad&gt; baz</#{tag_name.downcase}>"
      xhtmloutput = "<#{tag_name} title='1'>foo &lt;bad&gt;bar&lt;/bad&gt; baz</#{tag_name}>"
      rexmloutput = xhtmloutput

      if tag_name == 'image'
        htmloutput = "<img title='1'/>foo &lt;bad&gt;bar&lt;/bad&gt; baz"
        xhtmloutput = htmloutput
        rexmloutput = "<image title='1'>foo &lt;bad&gt;bar&lt;/bad&gt; baz</image>"
      elsif VOID_ELEMENTS.include?(tag_name)
        htmloutput = "<#{tag_name} title='1'/>foo &lt;bad&gt;bar&lt;/bad&gt; baz"
        xhtmloutput = htmloutput
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

  def test_should_allow_anchors
    input = "<a href='foo' onclick='bar'><script>baz</script></a>"
    output = "<a href='foo'>&lt;script&gt;baz&lt;/script&gt;</a>"
    check_sanitization(input, output, output, output)
  end

  # RFC 3986, sec 4.2
  def test_allow_colons_in_path_component
    input = "<a href=\"./this:that\">foo</a>"
    output = "<a href='./this:that'>foo</a>"
    check_sanitization(input, output, output, output)
  end

  %w(src width height alt).each do |img_attr|
    define_method "test_should_allow_image_#{img_attr}_attribute" do
      input = "<img #{img_attr}='foo' onclick='bar' />"
      output = "<img #{img_attr}='foo'/>"
      rexmloutput = "<img #{img_attr}='foo' />"
      check_sanitization(input, output, output, rexmloutput)
    end
  end

  def test_should_handle_non_html
    input = 'abc'
    output = 'abc'
    check_sanitization(input, output, output, output)
  end

  def test_should_handle_blank_text
    input = ''
    output = ''
    check_sanitization(input, output, output, output)
  end

  [%w(img src), %w(a href)].each do |(tag, attr)|
    close = VOID_ELEMENTS.include?(tag) ? "/>boo" : ">boo</#{tag}>"
    xclose = VOID_ELEMENTS.include?(tag) ? " />" : ">boo</#{tag}>"

    input = %(<#{tag} #{attr}="javascript:XSS" title="1">boo</#{tag}>)
    output = %(<#{tag} title='1'#{close})
    rexmloutput = %(<#{tag} title='1'#{xclose})
    define_method "test_should_strip_#{attr}_attribute_in_#{tag}_with_bad_protocols" do
      check_sanitization(input, output, output, rexmloutput)
    end

    define_method "test_should_strip_#{attr}_attribute_in_#{tag}_with_bad_protocols_and_whitespace" do
      input = %(<#{tag} #{attr}=" javascript:XSS" title="1">boo</#{tag}>)
      output = %(<#{tag} title='1'#{close})
      rexmloutput = %(<#{tag} title='1'#{xclose})
      check_sanitization(input, output, output, rexmloutput)
    end
  end

  [%(<img src="javascript:alert('XSS');" />),
   %(<img src=javascript:alert('XSS') />),
   %(<img src="JaVaScRiPt:alert('XSS')" />),
   %(<img src='javascript:alert(&quot;XSS&quot;)' />),
   %(<img src='javascript:alert(String.fromCharCode(88,83,83))' />),
   %(<img src='&#106;&#97;&#118;&#97;&#115;&#99;&#114;&#105;&#112;&#116;&#58;&#97;&#108;&#101;&#114;&#116;&#40;&#39;&#88;&#83;&#83;&#39;&#41;' />),
   %(<img src='&#0000106;&#0000097;&#0000118;&#0000097;&#0000115;&#0000099;&#0000114;&#0000105;&#0000112;&#0000116;&#0000058;&#0000097;&#0000108;&#0000101;&#0000114;&#0000116;&#0000040;&#0000039;&#0000088;&#0000083;&#0000083;&#0000039;&#0000041' />),
   %(<img src='&#x6A;&#x61;&#x76;&#x61;&#x73;&#x63;&#x72;&#x69;&#x70;&#x74;&#x3A;&#x61;&#x6C;&#x65;&#x72;&#x74;&#x28;&#x27;&#x58;&#x53;&#x53;&#x27;&#x29' />),
   %(<img src="jav\tascript:alert('XSS');" />),
   %(<img src="jav&#x09;ascript:alert('XSS');" />),
   %(<img src="jav&#x0A;ascript:alert('XSS');" />),
   %(<img src="jav&#x0D;ascript:alert('XSS');" />),
   %(<img src=" &#14;  javascript:alert('XSS');" />),
   %(<img src="&#x20;javascript:alert('XSS');" />),
   %(<img src="&#xA0;javascript:alert('XSS');" />)].each_with_index do |img_hack, i|
    define_method "test_should_not_fall_for_xss_image_hack_#{i}" do
      output = "<img/>"
      rexmloutput = "<img />"
      rexmloutput = "Ill-formed XHTML!" if i == 1
      check_sanitization(img_hack, output, output, rexmloutput)
    end
  end

  def test_should_sanitize_tag_broken_up_by_null
    input = %(<scr\0ipt>alert(\"XSS\")</scr\0ipt>)
    output = "&lt;scr\357\277\275ipt&gt;alert(\"XSS\")&lt;/scr\357\277\275ipt&gt;"
    rexmloutput = "Ill-formed XHTML!"
    check_sanitization(input, output, output, rexmloutput)
  end

  def test_should_sanitize_invalid_script_tag
    input = %(<script/XSS SRC="http://ha.ckers.org/xss.js"></script>)
    output = "&lt;script XSS=\"\" SRC=\"http://ha.ckers.org/xss.js\"&gt;&lt;/script&gt;"
    rexmloutput = "Ill-formed XHTML!"
    check_sanitization(input, output, output, rexmloutput)
  end

  def test_should_sanitize_script_tag_with_multiple_open_brackets
    input = %(<<script>alert("XSS");//<</script>)
    output = "&lt;&lt;script&gt;alert(\"XSS\");//&lt;&lt;/script&gt;"
    rexmloutput = "Ill-formed XHTML!"
    check_sanitization(input, output, output, rexmloutput)

    input = %(<iframe src=http://ha.ckers.org/scriptlet.html\n<)
    output = %(&lt;iframe src=\"http://ha.ckers.org/scriptlet.html\"&gt;&lt;)
    rexmloutput = "Ill-formed XHTML!"
    check_sanitization(input, output, output, rexmloutput)
  end

  def test_should_sanitize_unclosed_script
    input = %(<script src=http://ha.ckers.org/xss.js?<b>)
    output = "&lt;script src=\"http://ha.ckers.org/xss.js?\"&gt;<b/>"
    rexmloutput = "Ill-formed XHTML!"
    check_sanitization(input, output, output, rexmloutput)
  end

  def test_should_sanitize_half_open_scripts
    input = %(<img src="javascript:alert('XSS')")
    output = "<img/>"
    rexmloutput = "Ill-formed XHTML!"
    check_sanitization(input, output, output, rexmloutput)
  end

  def test_should_not_fall_for_ridiculous_hack
    img_hack = %(<img\nsrc\n=\n"\nj\na\nv\na\ns\nc\nr\ni\np\nt\n:\na\nl\ne\nr\nt\n(\n'\nX\nS\nS\n'\n)\n"\n />)
    output = "<img/>"
    rexmloutput = "<img />"
    check_sanitization(img_hack, output, output, rexmloutput)
  end

  def test_platypus
    input = %(<a href="http://www.ragingplatypus.com/" style="display:block; position:absolute; left:0; top:0; width:100%; height:100%; z-index:1; background-color:black; background-image:url(http://www.ragingplatypus.com/i/cam-full.jpg); background-x:center; background-y:center; background-repeat:repeat;">never trust your upstream platypus</a>)
    output = %(<a href='http://www.ragingplatypus.com/' style='display: block; width: 100%; height: 100%; background-color: black; background-x: center; background-y: center;'>never trust your upstream platypus</a>)
    check_sanitization(input, output, output, output)
  end

  def test_xul
    input = %(<p style="-moz-binding:url('http://ha.ckers.org/xssmoz.xml#xss')">fubar</p>)
    output = %(<p style=''>fubar</p>)
    check_sanitization(input, output, output, output)
  end

  def test_input_image
    input = %(<input type="image" src="javascript:alert('XSS');" />)
    output = %(<input type='image'/>)
    rexmloutput = %(<input type='image' />)
    check_sanitization(input, output, output, rexmloutput)
  end

  def test_non_alpha_non_digit
    input = %(<script/XSS src="http://ha.ckers.org/xss.js"></script>)
    output = "&lt;script XSS=\"\" src=\"http://ha.ckers.org/xss.js\"&gt;&lt;/script&gt;"
    rexmloutput = "Ill-formed XHTML!"
    check_sanitization(input, output, output, rexmloutput)

    input = '<a onclick!#$%&()*~+-_.,:;?@[/|\]^`=alert("XSS")>foo</a>'
    output =  "<a>foo</a>"
    rexmloutput = "Ill-formed XHTML!"
    check_sanitization(input, output, output, rexmloutput)

    input = '<img/src="http://ha.ckers.org/xss.js"/>'
    output = "<img src='http://ha.ckers.org/xss.js'/>"
    rexmloutput =  "Ill-formed XHTML!"
    check_sanitization(input, output, output, rexmloutput)
  end

  def test_img_dynsrc_lowsrc
    input = %(<img dynsrc="javascript:alert('XSS')" />)
    output = "<img/>"
    rexmloutput = "<img />"
    check_sanitization(input, output, output, rexmloutput)
  end

  def test_div_background_image_unicode_encoded
    input = %(<div style="background-image:\0075\0072\006C\0028'\006a\0061\0076\0061\0073\0063\0072\0069\0070\0074\003a\0061\006c\0065\0072\0074\0028.1027\0058.1053\0053\0027\0029'\0029">foo</div>)
    output = "<div style=''>foo</div>"
    check_sanitization(input, output, output, output)
  end

  def test_div_expression
    input = %(<div style="width: expression(alert('XSS'));">foo</div>)
    output = "<div style=''>foo</div>"
    check_sanitization(input, output, output, output)
  end

  def test_img_vbscript
    input = %(<img src='vbscript:msgbox("XSS")' />)
    output = '<img/>'
    rexmloutput = '<img />'
    check_sanitization(input, output, output, rexmloutput)
  end

  def test_should_handle_astral_plane_characters
    input = "<p>&#x1d4b5; &#x1d538;</p>"
    output = "<p>\360\235\222\265 \360\235\224\270</p>"
    check_sanitization(input, output, output, output)

    input = "<p><tspan>\360\235\224\270</tspan> a</p>"
    output = "<p><tspan>\360\235\224\270</tspan> a</p>"
    check_sanitization(input, output, output, output)
  end
end
