module Sanitize

# This module provides sanitization of XHTML+MathML+SVG 
# and of inline style attributes.
#
# Uses the HTML5lib parser, so that the parsing behaviour should
# resemble that of browsers.
#
#  sanitize_xhtml() is a case-sensitive sanitizer, suitable for XHTML
#  sanitize_html() is a case-insensitive sanitizer suitable for HTML
#  sanitize_rexml() sanitized a REXML tree, returning a string


  require 'html5lib/html5parser'
  require 'html5lib/liberalxmlparser'

  require 'html5lib/treewalkers'
  require 'html5lib/serializer'
  require 'string_utils'
  require 'html5lib/sanitizer'

  include HTML5lib

  def sanitize_xhtml(html)
    XHTMLParser.parseFragment(html.to_ncr, {:tokenizer => HTMLSanitizer, :encoding=>'utf-8' }).to_s
  end

  def sanitize_html(html)
    HTMLParser.parseFragment(html, {:tokenizer => HTMLSanitizer, :encoding=>'utf-8' }).to_s
  end

  def sanitize_rexml(tree)
    tokens = TreeWalkers.getTreeWalker('rexml').new(tree.to_ncr)
    HTMLSerializer.serialize(tokens, {:encoding=>'utf-8',
      :quote_attr_values => true,
      :minimize_boolean_attributes => false,
      :use_trailing_solidus => true,
      :space_before_trailing_solidus => true,
      :omit_optional_tags => false,
      :inject_meta_charset => false,
      :sanitize => true})
  end
end
