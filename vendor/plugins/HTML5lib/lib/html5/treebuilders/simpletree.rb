require 'html5/treebuilders/base'

module HTML5
  module TreeBuilders
    module SimpleTree

      class Node < Base::Node
        # Node representing an item in the tree.
        # name - The tag name associated with the node
        attr_accessor :name

        # The value of the current node (applies to text nodes and 
        # comments
        attr_accessor :value

        # a dict holding name, value pairs for attributes of the node
        attr_accessor :attributes

        def initialize name
          super
          @name       = name
          @value      = nil
          @attributes = {}
        end

        def appendChild node
          if node.kind_of? TextNode and 
            childNodes.length > 0 and childNodes.last.kind_of? TextNode
            childNodes.last.value += node.value
          else
            childNodes << node
          end
          node.parent = self
        end

        def removeChild node
           childNodes.delete node
           node.parent = nil
        end

        def cloneNode
          newNode = self.class.new name
          attributes.each {|name,value| newNode.attributes[name] = value}
          newNode.value = value
          newNode
        end

        def insertText data, before=nil
          if before
            insertBefore TextNode.new(data), before
          else
            appendChild TextNode.new(data)
          end
        end

        def insertBefore node, refNode
          index = childNodes.index(refNode)
          if node.kind_of?(TextNode) && index > 0 && childNodes[index-1].kind_of?(TextNode)
            childNodes[index-1].value += node.value
          else
            childNodes.insert index, node
          end
        end

        def printTree indent=0
          tree = "\n|%s%s" % [' '* indent, self.to_s]
          for child in childNodes
            tree += child.printTree(indent + 2)
          end
          return tree
        end

        def hasContent
          childNodes.length > 0
        end
      end

      class Element < Node
        def to_s
           "<#{name}>"
        end

        def printTree indent=0
          tree = "\n|%s%s" % [' '* indent, self.to_s]
          indent += 2
          for name, value in attributes
            tree += "\n|%s%s=\"%s\"" % [' ' * indent, name, value]
          end
          for child in childNodes
            tree += child.printTree(indent)
          end
          tree
        end
      end

      class Document < Node
        def to_s
           "#document"
        end

        def initialize
          super nil
        end

        def printTree indent=0
          tree = to_s
          for child in childNodes
            tree += child.printTree(indent + 2)
          end
          tree
        end
      end

      class DocumentType < Node
        attr_accessor :public_id, :system_id

        def to_s
          "<!DOCTYPE #{name}>"
        end

        def initialize name
          super name
          @public_id = nil
          @system_id = nil
        end
      end

      class DocumentFragment < Element
        def initialize
          super nil
        end

        def printTree indent=0
          tree = ""
          for child in childNodes
            tree += child.printTree(indent+2)
          end
          return tree
        end
      end

      class TextNode < Node
        def initialize value
          super nil
          @value = value
        end

        def to_s
           '"%s"' % value
        end
      end

      class CommentNode < Node
        def initialize value
          super nil
          @value = value
        end

        def to_s
          "<!-- %s -->" % value
        end
      end

      class TreeBuilder < Base::TreeBuilder
        def initialize
          @documentClass = Document
          @doctypeClass  = DocumentType
          @elementClass  = Element
          @commentClass  = CommentNode
          @fragmentClass = DocumentFragment
        end

        def testSerializer node
          node.printTree
        end

        def get_fragment
          @document = super
          @document
        end
      end

    end
  end
end
