#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__), 'preamble')

require 'html5lib/sanitizer'
require 'html5lib/html5parser'
require 'html5lib/liberalxmlparser'

class SanitizeTest < Test::Unit::TestCase
  include HTML5lib

  def sanitize_xhtml stream
    XHTMLParser.parseFragment(stream, :tokenizer => HTMLSanitizer).join('').gsub(/'/,'"')
  end

  def sanitize_html stream
    HTMLParser.parseFragment(stream, :tokenizer => HTMLSanitizer).join('').gsub(/'/,'"')
  end

  HTMLSanitizer::ALLOWED_ELEMENTS.each do |tag_name|
    next if %w[caption col colgroup optgroup option table tbody td tfoot th thead tr].include?(tag_name) ### TODO
    define_method "test_should_allow_#{tag_name}_tag" do
      if tag_name == 'image'
        assert_equal "<img title=\"1\"/>foo &lt;bad&gt;bar&lt;/bad&gt; baz",
          sanitize_html("<#{tag_name} title='1'>foo <bad>bar</bad> baz</#{tag_name}>")
      elsif VOID_ELEMENTS.include?(tag_name)
        assert_equal "<#{tag_name} title=\"1\"/>foo &lt;bad&gt;bar&lt;/bad&gt; baz",
          sanitize_html("<#{tag_name} title='1'>foo <bad>bar</bad> baz</#{tag_name}>")
      else
        assert_equal "<#{tag_name.downcase} title=\"1\">foo &lt;bad&gt;bar&lt;/bad&gt; baz</#{tag_name.downcase}>",
          sanitize_html("<#{tag_name} title='1'>foo <bad>bar</bad> baz</#{tag_name}>")
        assert_equal "<#{tag_name} title=\"1\">foo &lt;bad&gt;bar&lt;/bad&gt; baz</#{tag_name}>",
          sanitize_xhtml("<#{tag_name} title='1'>foo <bad>bar</bad> baz</#{tag_name}>")
      end
    end
  end

  HTMLSanitizer::ALLOWED_ELEMENTS.each do |tag_name|
    define_method "test_should_forbid_#{tag_name.upcase}_tag" do
      assert_equal "&lt;#{tag_name.upcase} title=\"1\"&gt;foo &lt;bad&gt;bar&lt;/bad&gt; baz&lt;/#{tag_name.upcase}&gt;",
        sanitize_html("<#{tag_name.upcase} title='1'>foo <bad>bar</bad> baz</#{tag_name.upcase}>")
    end
  end

  HTMLSanitizer::ALLOWED_ATTRIBUTES.each do |attribute_name|
    next if attribute_name == 'style'
    define_method "test_should_allow_#{attribute_name}_attribute" do
      assert_equal "<p #{attribute_name.downcase}=\"foo\">foo &lt;bad&gt;bar&lt;/bad&gt; baz</p>",
        sanitize_html("<p #{attribute_name}='foo'>foo <bad>bar</bad> baz</p>")
      assert_equal "<p #{attribute_name}=\"foo\">foo &lt;bad&gt;bar&lt;/bad&gt; baz</p>",
        sanitize_xhtml("<p #{attribute_name}='foo'>foo <bad>bar</bad> baz</p>")
    end
  end

  HTMLSanitizer::ALLOWED_ATTRIBUTES.each do |attribute_name|
    define_method "test_should_forbid_#{attribute_name.upcase}_attribute" do
      assert_equal "<p>foo &lt;bad&gt;bar&lt;/bad&gt; baz</p>",
        sanitize_html("<p #{attribute_name.upcase}='display: none;'>foo <bad>bar</bad> baz</p>")
    end
  end

  HTMLSanitizer::ALLOWED_PROTOCOLS.each do |protocol|
    define_method "test_should_allow_#{protocol}_uris" do
      assert_equal "<a href=\"#{protocol}\">foo</a>",
        sanitize_html(%(<a href="#{protocol}">foo</a>))
    end
  end

  HTMLSanitizer::ALLOWED_PROTOCOLS.each do |protocol|
    define_method "test_should_allow_uppercase_#{protocol}_uris" do
      assert_equal "<a href=\"#{protocol.upcase}\">foo</a>",
        sanitize_html(%(<a href="#{protocol.upcase}">foo</a>))
    end
  end

  def test_should_allow_anchors
    assert_equal "<a href=\"foo\">&lt;script&gt;baz&lt;/script&gt;</a>",
     sanitize_html("<a href='foo' onclick='bar'><script>baz</script></a>")
  end

  # RFC 3986, sec 4.2
  def test_allow_colons_in_path_component
    assert_equal "<a href=\"./this:that\">foo</a>",
      sanitize_html("<a href=\"./this:that\">foo</a>")
  end

  %w(src width height alt).each do |img_attr|
    define_method "test_should_allow_image_#{img_attr}_attribute" do
      assert_equal "<img #{img_attr}=\"foo\"/>",
        sanitize_html("<img #{img_attr}='foo' onclick='bar' />")
    end
  end

  def test_should_handle_non_html
    assert_equal 'abc',  sanitize_html("abc")
  end

  def test_should_handle_blank_text
    assert_equal '', sanitize_html('')
  end

  [%w(img src), %w(a href)].each do |(tag, attr)|
    close = VOID_ELEMENTS.include?(tag) ? "/>boo" : ">boo</#{tag}>"

    define_method "test_should_strip_#{attr}_attribute_in_#{tag}_with_bad_protocols" do
      assert_equal %(<#{tag} title="1"#{close}), sanitize_html(%(<#{tag} #{attr}="javascript:XSS" title="1">boo</#{tag}>))
    end

    define_method "test_should_strip_#{attr}_attribute_in_#{tag}_with_bad_protocols_and_whitespace" do
      assert_equal %(<#{tag} title="1"#{close}), sanitize_html(%(<#{tag} #{attr}=" javascript:XSS" title="1">boo</#{tag}>))
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
      assert_equal "<img/>", sanitize_html(img_hack)
    end
  end

  def test_should_sanitize_tag_broken_up_by_null
    assert_equal "&lt;scr\357\277\275ipt&gt;alert(\"XSS\")&lt;/scr\357\277\275ipt&gt;", sanitize_html(%(<scr\0ipt>alert(\"XSS\")</scr\0ipt>))
  end

  def test_should_sanitize_invalid_script_tag
    assert_equal "&lt;script XSS=\"\" SRC=\"http://ha.ckers.org/xss.js\"&gt;&lt;/script&gt;", sanitize_html(%(<script/XSS SRC="http://ha.ckers.org/xss.js"></script>))
  end

  def test_should_sanitize_script_tag_with_multiple_open_brackets
    assert_equal "&lt;&lt;script&gt;alert(\"XSS\");//&lt;&lt;/script&gt;", sanitize_html(%(<<script>alert("XSS");//<</script>))
    assert_equal %(&lt;iframe src=\"http://ha.ckers.org/scriptlet.html\"&gt;&lt;), sanitize_html(%(<iframe src=http://ha.ckers.org/scriptlet.html\n<))
  end

  def test_should_sanitize_unclosed_script
    assert_equal "&lt;script src=\"http://ha.ckers.org/xss.js?\"&gt;<b/>", sanitize_html(%(<script src=http://ha.ckers.org/xss.js?<b>))
  end

  def test_should_sanitize_half_open_scripts
    assert_equal  "<img/>", sanitize_html(%(<img src="javascript:alert('XSS')"))
  end

  def test_should_not_fall_for_ridiculous_hack
    img_hack = %(<img\nsrc\n=\n"\nj\na\nv\na\ns\nc\nr\ni\np\nt\n:\na\nl\ne\nr\nt\n(\n'\nX\nS\nS\n'\n)\n"\n />)
    assert_equal "<img/>", sanitize_html(img_hack)
  end

  def test_platypus
    assert_equal %(<a href=\"http://www.ragingplatypus.com/\" style=\"display: block; width: 100%; height: 100%; background-color: black; background-x: center; background-y: center;\">never trust your upstream platypus</a>),
       sanitize_html(%(<a href="http://www.ragingplatypus.com/" style="display:block; position:absolute; left:0; top:0; width:100%; height:100%; z-index:1; background-color:black; background-image:url(http://www.ragingplatypus.com/i/cam-full.jpg); background-x:center; background-y:center; background-repeat:repeat;">never trust your upstream platypus</a>))
  end

  def test_xul
    assert_equal %(<p style="">fubar</p>),
     sanitize_html(%(<p style="-moz-binding:url('http://ha.ckers.org/xssmoz.xml#xss')">fubar</p>))
  end

  def test_input_image
    assert_equal %(<input type="image"/>),
      sanitize_html(%(<input type="image" src="javascript:alert('XSS');" />))
  end

  def test_non_alpha_non_digit
    assert_equal "&lt;script XSS=\"\" src=\"http://ha.ckers.org/xss.js\"&gt;&lt;/script&gt;",
      sanitize_html(%(<script/XSS src="http://ha.ckers.org/xss.js"></script>))
    assert_equal "<a>foo</a>",
      sanitize_html('<a onclick!#$%&()*~+-_.,:;?@[/|\]^`=alert("XSS")>foo</a>')
    assert_equal "<img src=\"http://ha.ckers.org/xss.js\"/>",
      sanitize_html('<img/src="http://ha.ckers.org/xss.js"/>')
  end

  def test_img_dynsrc_lowsrc
     assert_equal "<img/>",
       sanitize_html(%(<img dynsrc="javascript:alert('XSS')" />))
     assert_equal "<img/>",
       sanitize_html(%(<img lowsrc="javascript:alert('XSS')" />))
  end

  def test_div_background_image_unicode_encoded
    assert_equal '<div style="">foo</div>',
      sanitize_html(%(<div style="background-image:\0075\0072\006C\0028'\006a\0061\0076\0061\0073\0063\0072\0069\0070\0074\003a\0061\006c\0065\0072\0074\0028.1027\0058.1053\0053\0027\0029'\0029">foo</div>))
  end

  def test_div_expression
    assert_equal '<div style="">foo</div>',
      sanitize_html(%(<div style="width: expression(alert('XSS'));">foo</div>))
  end

  def test_img_vbscript
     assert_equal '<img/>',
       sanitize_html(%(<img src='vbscript:msgbox("XSS")' />))
  end

end
