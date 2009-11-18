# == Introduction
#
# This module provides sanitization of XHTML+MathML+SVG 
# and of inline style attributes. Its genesis is {described here}[http://golem.ph.utexas.edu/~distler/blog/archives/001181.html].
#
# Uses the {HTML5lib parser}[http://code.google.com/p/html5lib/], so that the parsing behaviour should
# resemble that of browsers.
#
#  sanitize_xhtml() is a case-sensitive sanitizer, suitable for XHTML
#  sanitize_html() is a case-insensitive sanitizer suitable for HTML
#  sanitize_rexml() sanitizes a REXML tree, returning a string
#  safe_sanitize_xhtml() makes extra-sure that the result is well-formed XHTML
#                        by running the output of sanitize_xhtml() through REXML
#
# == Files
#
# {sanitize.rb}[http://golem.ph.utexas.edu/~distler/code/instiki/svn/lib/sanitize.rb],
# {HTML5lib}[http://golem.ph.utexas.edu/~distler/code/instiki/svn/vendor/plugins/HTML5lib/]
#
# == Author
#
# {Jacques Distler}[http://golem.ph.utexas.edu/~distler/]
#
# ==  License
#
# Ruby License

module Sanitize

  require 'html5/html5parser'
  require 'html5/liberalxmlparser'
  require 'html5/treewalkers'
  require 'html5/treebuilders'
  require 'html5/serializer'
  require 'html5/sanitizer'
  require 'stringsupport.rb'

  include HTML5

# Sanitize a string, parsed using XHTML parsing rules.
#
# :call-seq:
#    sanitize_xhtml(string)                    -> string
#    sanitize_xhtml(string, {:encoding => 'iso-8859-1', :to_tree => true}) -> REXML::Document
#
# Unless otherwise specified, the string is assumed to be utf-8 encoded.
# By default, the output is a string. But, optionally, you can return a REXML tree.
#
# The string returned is utf-8 encoded. If you want, you can use iconv to convert it to some other encoding.
# (REXML trees are always utf-8 encoded.)
  def sanitize_xhtml(html, options = {})
    @encoding = 'utf-8'
    @treebuilder = TreeBuilders::REXML::TreeBuilder
    @to_tree = false
    options.each do |name, value|
      next unless %w(encoding treebuilder to_tree).include? name.to_s
      if name.to_s == 'treebuilder'
        @treebuilder =  HTML5lib::TreeBuilders.get_tree_builder(value)
      else
        instance_variable_set("@#{name}", value)
      end
    end
    if @encoding == 'utf-8'
      parsed = XHTMLParser.parse_fragment(html.to_utf8, {:tokenizer => HTMLSanitizer,
        :lowercase_element_name => false, :lowercase_attr_name => false,
        :encoding => @encoding, :tree => @treebuilder })
    else
      parsed = XHTMLParser.parse_fragment(html.to_ncr, {:tokenizer => HTMLSanitizer,
        :lowercase_element_name => false, :lowercase_attr_name => false,
        :encoding => @encoding, :tree => @treebuilder })
    end      
    return parsed if @to_tree
    return parsed.to_s
  end
  
# Sanitize a string, parsed using XHTML parsing rules. Reparse the result to
#    ensure well-formedness. 
#
# :call-seq:
#    safe_sanitize_xhtml(string)                    -> string
#
# Unless otherwise specified, the string is assumed to be utf-8 encoded.
#
# The string returned is utf-8 encoded. If you want, you can use iconv to convert it to some other encoding.
# (REXML trees are always utf-8 encoded.)
  def safe_sanitize_xhtml(html, options = {})
    options[:to_tree] = false
    sanitized = sanitize_xhtml(html, options)
    doc = REXML::Document.new("<div xmlns='http://www.w3.org/1999/xhtml'>#{sanitized}</div>")
    sanitized = doc.to_s.gsub(/\A<div xmlns='http:\/\/www.w3.org\/1999\/xhtml'>(.*)<\/div>\Z/m, '\1')
    rescue REXML::ParseException
      sanitized = sanitized.escapeHTML
  end 

# Sanitize a string, parsed using HTML parsing rules.
#
# :call-seq:
#    sanitize_html( string )                    ->  string
#    sanitize_html( string, {:encoding => 'iso-8859-1', :to_tree => true} ) ->  REXML::Document
#
# Unless otherwise specified, the string is assumed to be utf-8 encoded.
# By default, the output is a string. But, optionally, you can return a REXML tree.
#
# The string returned is utf-8 encoded. If you want, you can use iconv to convert it to some other encoding.
# (REXML trees are always utf-8 encoded.)
  def sanitize_html(html, options = {})
    @encoding = 'utf-8'
    @treebuilder = TreeBuilders::REXML::TreeBuilder
    @to_tree = false
    options.each do |name, value|
      next unless %w(encoding treebuilder to_tree).include? name.to_s
      if name.to_s == 'treebuilder'
        @treebuilder =  HTML5lib::TreeBuilders.get_tree_builder(value)
      else
        instance_variable_set("@#{name}", value)
      end
    end
    if @encoding == 'utf-8'
      parsed = HTMLParser.parse_fragment(html.to_utf8, {:tokenizer => HTMLSanitizer,
        :encoding => @encoding, :tree => @treebuilder })
    else
      parsed = HTMLParser.parse_fragment(html.to_ncr, {:tokenizer => HTMLSanitizer,
        :encoding => @encoding, :tree => @treebuilder })
    end 
    return parsed if @to_tree
    return parsed.to_s
  end

# Sanitize a REXML tree. The output is a string.
#
# :call-seq:
#    sanitize_rexml(tree)                    -> string
#
  def sanitize_rexml(tree)
    tokens = TreeWalkers.get_tree_walker('rexml2').new(tree)
    XHTMLSerializer.serialize(tokens, {:encoding=>'utf-8',
      :space_before_trailing_solidus => true,
      :inject_meta_charset => false,
      :sanitize => true})
  end
end

require 'rexml/element'
module REXML #:nodoc:
  class Element

# Convert XHTML+MathML Named Entities in a REXML::Element to Numeric Character References
#
#  :call-seq:
#     tree.to_ncr  -> REXML::Element
#
# REXML, typically, converts NCRs to utf-8 characters, which is what you'll see when you
# access the resulting REXML document.
#
# Note that this method needs to traverse the entire tree, converting text nodes and attributes
# for each element. This can be SLOW. It will often be faster to serialize to a string and then
# use String.to_ncr instead.
#
    def to_ncr
      self.each_element { |el|
        el.texts.each_index  {|i|
          el.texts[i].value = el.texts[i].to_s.to_ncr
        }
        el.attributes.each { |name,val|
          el.attributes[name] = val.to_ncr
        }
        el.to_ncr if el.has_elements?
      }
      return self
    end
    
# Convert XHTML+MathML Named Entities in a REXML::Element to UTF-8
#
#  :call-seq:
#     tree.to_utf8  -> REXML::Element
#
# Note that this method needs to traverse the entire tree, converting text nodes and attributes 
# for each element. This can be SLOW. It will often be faster to serialize to a string and then
# use String.to_utf8 instead.
#
    def to_utf8
      self.each_element { |el|
        el.texts.each_index  {|i|
          el.texts[i].value = el.texts[i].to_s.to_utf8
        }
        el.attributes.each { |name,val|
          el.attributes[name] = val.to_utf8
        }
        el.to_utf8 if el.has_elements?
      }
      return self
    end

  end
end

module HTML5 #:nodoc: all
  module TreeWalkers

    private

    class << self
      def [](name)
        case name.to_s.downcase
        when 'rexml'
          require 'html5/treewalkers/rexml'
          REXML::TreeWalker
        when 'rexml2'
          REXML2::TreeWalker
        else
          raise "Unknown TreeWalker #{name}"
        end
      end

      alias :get_tree_walker :[]
    end

    module REXML2
      class TreeWalker < HTML5::TreeWalkers::NonRecursiveTreeWalker

        private

        def node_details(node)
          case node
          when ::REXML::Document
            [:DOCUMENT]
          when ::REXML::Element
            if !node.name
              [:DOCUMENT_FRAGMENT]
            else
              [:ELEMENT, node.name,
                node.attributes.map {|name,value| [name,value.to_utf8]},
                node.has_elements? || node.has_text?]
            end
          when ::REXML::Text
            [:TEXT, node.value.to_utf8]
          when ::REXML::Comment
            [:COMMENT, node.string]
          when ::REXML::DocType
            [:DOCTYPE, node.name, node.public, node.system]
          when ::REXML::XMLDecl
            [nil]
          else
            [:UNKNOWN, node.class.inspect]
          end
        end

        def first_child(node)
          node.children.first
        end

        def next_sibling(node)
          node.next_sibling
        end

        def parent(node)
          node.parent
        end
      end
    end
  end
end
