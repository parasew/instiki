module Sanitize

# This module provides sanitization of XHTML+MathML+SVG 
# and of inline style attributes.
#
# Uses the HTML5lib parser, so that the parsing behaviour should
# resemble that of browsers.
#
#  sanitize_xhtml() is a case-sensitive sanitizer, suitable for XHTML
#  sanitize_html() is a case-insensitive sanitizer suitable for HTML


  require 'html5lib/sanitizer'
  require 'html5lib/html5parser'
  require 'html5lib/liberalxmlparser'
  include HTML5lib

  def sanitize_xhtml(html)
    XHTMLParser.parseFragment(html, :tokenizer => HTMLSanitizer).to_s
  end

  def sanitize_html(html)
    HTMLParser.parseFragment(html, :tokenizer => HTMLSanitizer).to_s
  end

end
