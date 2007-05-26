require File.join(File.dirname(__FILE__), 'preamble')

require 'html5lib/liberalxmlparser'

XMLELEM = /<(\w+\s*)((?:[-:\w]+="[^"]*"\s*)+)(\/?)>/
SORTATTRS = '<#{$1+$2.split.sort.join(' ')+$3}>'

def assert_xml_equal(input, expected=nil, parser=HTML5lib::XMLParser)
    document = parser.parse(input.chomp).root
    if not expected
        expected = input.chomp.gsub(XMLELEM,SORTATTRS)
        expected = expected.gsub(/&#(\d+);/) {[$1.to_i].pack('U')}
        output = document.to_s.gsub(/'/,'"').gsub(XMLELEM,SORTATTRS)
        assert_equal(expected, output)
    else
        assert_equal(expected, document.to_s.gsub(/'/,'"'))
    end
end

def assert_xhtml_equal(input, expected=nil, parser=HTML5lib::XHTMLParser)
      assert_xml_equal(input, expected, parser)
end

class BasicXhtml5Test < Test::Unit::TestCase

  def test_title_body_mismatched_close
    assert_xhtml_equal(
      '<title>Xhtml</title><b><i>content</b></i>',
      '<html xmlns="http://www.w3.org/1999/xhtml">' +
        '<head><title>Xhtml</title></head>' + 
        '<body><b><i>content</i></b></body>' +
      '</html>')
  end

  def test_title_body_named_charref
    assert_xhtml_equal(
      '<title>mdash</title>A &mdash B',
      '<html xmlns="http://www.w3.org/1999/xhtml">' +
        '<head><title>mdash</title></head>' + 
        '<body>A '+ [0x2014].pack('U') + ' B</body>' +
      '</html>')
  end
end

class BasicXmlTest < Test::Unit::TestCase

  def test_comment
    assert_xml_equal("<x><!-- foo --></x>")
  end

  def test_cdata
    assert_xml_equal("<x><![CDATA[foo]]></x>","<x>foo</x>")
  end

  def test_simple_text
    assert_xml_equal("<p>foo</p>","<p>foo</p>")
  end

  def test_optional_close
    assert_xml_equal("<p>foo","<p>foo</p>")
  end

  def test_html_mismatched
    assert_xml_equal("<b><i>foo</b></i>","<b><i>foo</i></b>")
  end
end

class OpmlTest < Test::Unit::TestCase

  def test_mixedCaseElement
    assert_xml_equal(
      '<opml version="1.0">' +
        '<head><ownerName>Dave Winer</ownerName></head>' +
      '</opml>')
  end

  def test_mixedCaseAttribute
    assert_xml_equal(
      '<opml version="1.0">' +
        '<body><outline isComment="true"/></body>' +
      '</opml>')
  end

  def test_malformed
    assert_xml_equal(
      '<opml version="1.0">' +
        '<body><outline text="Odds & Ends"/></body>' +
      '</opml>',
      '<opml version="1.0">' +
        '<body><outline text="Odds &amp; Ends"/></body>' +
      '</opml>')
  end
end

class XhtmlTest < Test::Unit::TestCase

  def test_mathml
    assert_xhtml_equal <<EOX
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>MathML</title></head>
<body>
  <math xmlns="http://www.w3.org/1998/Math/MathML">
    <mrow>
      <mi>x</mi>
      <mo>=</mo>

      <mfrac>
        <mrow>
          <mrow>
            <mo>-</mo>
            <mi>b</mi>
          </mrow>
          <mo>&#177;</mo>
          <msqrt>

            <mrow>
              <msup>
                <mi>b</mi>
                <mn>2</mn>
              </msup>
              <mo>-</mo>
              <mrow>

                <mn>4</mn>
                <mo>&#8290;</mo>
                <mi>a</mi>
                <mo>&#8290;</mo>
                <mi>c</mi>
              </mrow>
            </mrow>

          </msqrt>
        </mrow>
        <mrow>
          <mn>2</mn>
          <mo>&#8290;</mo>
          <mi>a</mi>
        </mrow>
      </mfrac>

    </mrow>
  </math>
</body></html>
EOX
  end

  def test_svg
    assert_xhtml_equal <<EOX
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>SVG</title></head>
<body>
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <path d="M38,38c0-12,24-15,23-2c0,9-16,13-16,23v7h11v-4c0-9,17-12,17-27
             c-2-22-45-22-45,3zM45,70h11v11h-11z" fill="#371">
    </path>
    <circle cx="50" cy="50" r="45" fill="none" stroke="#371" stroke-width="10">
    </circle>

  </svg>
</body></html>
EOX
  end

  def test_xlink
    assert_xhtml_equal <<EOX
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>XLINK</title></head>
<body>
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs xmlns:l="http://www.w3.org/1999/xlink">
      <radialGradient id="s1" fx=".4" fy=".2" r=".7">
        <stop stop-color="#FE8"/>
        <stop stop-color="#D70" offset="1"/>
      </radialGradient>
      <radialGradient id="s2" fx=".8" fy=".5" l:href="#s1"/>
      <radialGradient id="s3" fx=".5" fy=".9" l:href="#s1"/>
      <radialGradient id="s4" fx=".1" fy=".5" l:href="#s1"/>
    </defs>
    <g stroke="#940">
      <path d="M73,29c-37-40-62-24-52,4l6-7c-8-16,7-26,42,9z" fill="url(#s1)"/>
      <path d="M47,8c33-16,48,21,9,47l-6-5c38-27,20-44,5-37z" fill="url(#s2)"/>
      <path d="M77,32c22,30,10,57-39,51l-1-8c3,3,67,5,36-36z" fill="url(#s3)"/>

      <path d="M58,84c-4,20-38-4-8-24l-6-5c-36,43,15,56,23,27z" fill="url(#s4)"/>
      <path d="M40,14c-40,37-37,52-9,68l1-8c-16-13-29-21,16-56z" fill="url(#s1)"/>
      <path d="M31,33c19,23,20,7,35,41l-9,1.7c-4-19-8-14-31-37z" fill="url(#s2)"/>
    </g>
  </svg>
</body></html>
EOX
  end

  def test_br
    assert_xhtml_equal <<EOX
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>XLINK</title></head>
<body>
<br/>
</body></html>
EOX
  end

  def xtest_strong
    assert_xhtml_equal <<EOX
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>XLINK</title></head>
<body>
<strong></strong>
</body></html>
EOX
  end
end
