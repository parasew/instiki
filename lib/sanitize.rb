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
  require 'html5lib/treebuilders'
  require 'html5lib/serializer'
  require 'string_utils'
  require 'html5lib/sanitizer'

  include HTML5lib

# Sanitize a string, parsed using XHTML parsing rules.
#
# :call-seq:
#    sanitize_xhtml(string)                    -> string
#    sanitize_xhtml(string, {:encoding => 'iso-8859-1', :to_tree => true}) -> REXML::Document
#
# Unless otherwise specified, the string is assumed to be utf-8 encoded.
# By default, the output is a string. But, optionally, you can return a REXML tree.
  def sanitize_xhtml(html, options = {})
    @encoding = 'utf-8'
    @treebuilder = TreeBuilders::REXML::TreeBuilder
    @to_tree = false
    options.each do |name, value|
      next unless %w(encoding treebuilder to_tree).include? name.to_s
      if name.to_s == 'treebuilder'
        @treebuilder =  HTML5lib::TreeBuilders.getTreeBuilder(value)
      else
        instance_variable_set("@#{name}", value)
      end
    end
    parsed = XHTMLParser.parseFragment(html.to_ncr, {:tokenizer => HTMLSanitizer,
      :encoding => @encoding, :tree => @treebuilder })
    return parsed if @to_tree
    return parsed.to_s
  end

# Sanitize a string, parsed using HTML parsing rules.
#
# :call-seq:
#    sanitize_html(string)                    -> string
#    sanitize_html(string, {:encoding => 'iso-8859-1', :to_tree => true}) -> REXML::Document
#
# Unless otherwise specified, the string is assumed to be utf-8 encoded.
# By default, the output is a string. But, optionally, you can return a REXML tree.
  def sanitize_html(html, options = {})
    @encoding = 'utf-8'
    @treebuilder = TreeBuilders::REXML::TreeBuilder
    @to_tree = false
    options.each do |name, value|
      next unless %w(encoding treebuilder to_tree).include? name.to_s
      if name.to_s == 'treebuilder'
        @treebuilder =  HTML5lib::TreeBuilders.getTreeBuilder(value)
      else
        instance_variable_set("@#{name}", value)
      end
    end
    parsed = HTMLParser.parseFragment(html.to_ncr, {:tokenizer => HTMLSanitizer,
      :encoding => @encoding, :tree => @treebuilder })
    return parsed if @to_tree
    return parsed.to_s
  end

# Sanitize a REXML tree. The output is a string.
#
# :call-seq:
#    sanitize_rexml(tree)                    -> string
#
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
