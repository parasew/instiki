require 'html5lib/treebuilders/base'
require 'rubygems'
require 'hpricot'
require 'forwardable'

module HTML5lib
  module TreeBuilders
    module Hpricot

      class Node < Base::Node

        extend Forwardable

        def_delegators :@hpricot, :name

        attr_accessor :hpricot

        def initialize(name)
          super(name)
          @hpricot = self.class.hpricot_class.new name
        end

        def appendChild(node)
          if node.kind_of?(TextNode) and childNodes.any? and childNodes.last.kind_of?(TextNode)
            childNodes[-1].hpricot.content = childNodes[-1].hpricot.to_s + node.hpricot.to_s
          else
            childNodes << node
            hpricot.children << node.hpricot
          end
          if (oldparent = node.hpricot.parent) != nil
            oldparent.children.delete_at(oldparent.children.index(node.hpricot))
          end
          node.hpricot.parent = hpricot
          node.parent = self
        end

        def removeChild(node)
           childNodes.delete(node)
           hpricot.children.delete_at(hpricot.children.index(node.hpricot))
           node.hpricot.parent = nil
           node.parent = nil
        end

        def insertText(data, before=nil)
          if before
            insertBefore(TextNode.new(data), before)
          else
            appendChild(TextNode.new(data))
          end
        end

        def insertBefore(node, refNode)
          index = childNodes.index(refNode)
          if node.kind_of?(TextNode) and index > 0 and childNodes[index-1].kind_of?(TextNode)
            childNodes[index-1].hpricot.content = childNodes[index-1].hpricot.to_s + node.hpricot.to_s
          else
            refNode.hpricot.parent.insert_before(node.hpricot,refNode.hpricot)
            childNodes.insert(index, node)
          end
        end

        def hasContent
          childNodes.any?
        end
      end

      class Element < Node
        def self.hpricot_class
          ::Hpricot::Elem
        end

        def initialize(name)
          super(name)

          @hpricot = ::Hpricot::Elem.new(::Hpricot::STag.new(name))
        end

        def name
          @hpricot.stag.name
        end

        def cloneNode
          attributes.inject(self.class.new(name)) do |node, (name, value)|
            node.hpricot[name] = value
            node
          end
        end

        # A call to Hpricot::Elem#raw_attributes is built dynamically,
        # so alterations to the returned value (a hash) will be lost.
        #
        # AttributeProxy works around this by forwarding :[]= calls
        # to the raw_attributes accessor on the element start tag.
        #
        class AttributeProxy
          def initialize(hpricot)
            @hpricot = hpricot
          end

          def []=(k, v)
            @hpricot.stag.send(stag_attributes_method)[k] = v
          end

          def stag_attributes_method
            # STag#attributes changed to STag#raw_attributes after Hpricot 0.5
            @hpricot.stag.respond_to?(:raw_attributes) ? :raw_attributes : :attributes
          end

          def method_missing(*a, &b)
            @hpricot.attributes.send(*a, &b)
          end
        end

        def attributes
          AttributeProxy.new(@hpricot)
        end

        def attributes=(attrs)
          attrs.each { |name, value| @hpricot[name] = value }
        end

        def printTree(indent=0)
          tree = "\n|#{' ' * indent}<#{name}>"
          indent += 2
          attributes.each do |name, value|
            next if name == 'xmlns'
            tree += "\n|#{' ' * indent}#{name}=\"#{value}\""
          end
          childNodes.inject(tree) { |tree, child| tree + child.printTree(indent) }
        end
      end

      class Document < Node
        def self.hpricot_class
          ::Hpricot::Doc
        end

        def initialize
          super(nil)
        end

        def printTree(indent=0)
          childNodes.inject('#document') { |tree, child| tree + child.printTree(indent + 2) }
        end
      end

      class DocumentType < Node
        def self.hpricot_class
          ::Hpricot::DocType
        end

        def initialize(name)
          begin
            super(name)
          rescue ArgumentError # needs 3...
          end

          @hpricot = ::Hpricot::DocType.new(name, nil, nil)
        end

        def printTree(indent=0)
          "\n|#{' ' * indent}<!DOCTYPE #{hpricot.target}>"
        end
      end

      class DocumentFragment < Element
        def initialize
          super('')
        end

        def printTree(indent=0)
          childNodes.inject('') { |tree, child| tree + child.printTree(indent+2) }
        end
      end

      class TextNode < Node
        def initialize(data)
          @hpricot = ::Hpricot::Text.new(data)
        end

        def printTree(indent=0)
          "\n|#{' ' * indent}\"#{hpricot.content}\""
        end
      end

      class CommentNode < Node
        def self.hpricot_class
          ::Hpricot::Comment
        end

        def printTree(indent=0)
          "\n|#{' ' * indent}<!-- #{hpricot.content} -->"
        end
      end

      class TreeBuilder < Base::TreeBuilder
        def initialize
          @documentClass = Document
          @doctypeClass = DocumentType
          @elementClass = Element
          @commentClass = CommentNode
          @fragmentClass = DocumentFragment
        end

        def testSerializer(node)
          node.printTree
        end

        def getDocument
          @document.hpricot
        end

        def getFragment
          @document = super
          return @document.hpricot.children
        end
      end

    end
  end
end
