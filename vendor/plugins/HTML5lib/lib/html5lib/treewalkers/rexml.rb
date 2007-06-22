require 'html5lib/treewalkers/base'
require 'rexml/document'

module HTML5lib
  module TreeWalkers
    module REXML
      class TreeWalker < HTML5lib::TreeWalkers::NonRecursiveTreeWalker

        def node_details(node)
          case node
          when ::REXML::Document
            [:DOCUMENT]
          when ::REXML::Element
            if !node.name
              [:DOCUMENT_FRAGMENT]
            else
              [:ELEMENT, node.name,
                node.attributes.map {|name,value| [name,value]},
                node.has_elements? || node.has_text?]
            end
          when ::REXML::Text
            [:TEXT, node.value]
          when ::REXML::Comment
            [:COMMENT, node.string]
          when ::REXML::DocType
            [:DOCTYPE, node.name]
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
