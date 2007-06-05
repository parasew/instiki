require 'html5lib/treewalkers/base'

module HTML5lib
  module TreeWalkers
    module SimpleTree
      class TreeWalker < HTML5lib::TreeWalkers::Base
        include HTML5lib::TreeBuilders::SimpleTree

        def walk(node)
          case node
          when Document, DocumentFragment
            return

          when DocumentType
            yield doctype(node.name)

          when TextNode
            text(node.value) {|token| yield token}

          when Element
            if VOID_ELEMENTS.include?(node.name)
              yield emptyTag(node.name, node.attributes, node.hasContent())
            else
              yield startTag(node.name, node.attributes)
              for child in node.childNodes
                walk(child) {|token| yield token}
              end
              yield endTag(node.name)
            end

          when CommentNode
            yield comment(node.value)

          else
            puts '?'
            yield unknown(node.class)
          end
        end

        def each
          for child in @tree.childNodes
            walk(child) {|node| yield node}
          end
        end
      end
    end
  end
end
