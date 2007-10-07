require 'html5/treebuilders/base'
require 'rexml/document'
require 'forwardable'

module HTML5
  module TreeBuilders
    module REXML

      class Node < Base::Node
        extend Forwardable
        def_delegators :@rxobj, :name, :attributes
        attr_accessor :rxobj

        def initialize name
          super name
          @rxobj = self.class.rxclass.new name
        end

        def appendChild node
          if node.kind_of?(TextNode) && childNodes.length > 0 && childNodes.last.kind_of?(TextNode)
            childNodes.last.rxobj.value = childNodes.last.rxobj.to_s + node.rxobj.to_s
            childNodes.last.rxobj.raw = true
          else
            childNodes.push node
            rxobj.add node.rxobj
          end
          node.parent = self
        end

        def removeChild node
           childNodes.delete node
           rxobj.delete node.rxobj
           node.parent = nil
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
          if node.kind_of?(TextNode) and index > 0 && childNodes[index-1].kind_of?(TextNode)
            childNodes[index-1].rxobj.value = childNodes[index-1].rxobj.to_s + node.rxobj.to_s
            childNodes[index-1].rxobj.raw = true
          else
            childNodes.insert index, node
            refNode.rxobj.parent.insert_before(refNode.rxobj,node.rxobj)
          end
        end

        def hasContent
          (childNodes.length > 0)
        end
      end

      class Element < Node
        def self.rxclass
          ::REXML::Element
        end

        def initialize name
          super name
        end

        def cloneNode
          newNode = self.class.new name
          attributes.each {|name,value| newNode.attributes[name] = value}
          newNode
        end

        def attributes= value
          value.each {|name, value| rxobj.attributes[name] = value}
        end

        def printTree indent=0
          tree = "\n|#{' ' * indent}<#{name}>"
          indent += 2
          for name, value in attributes
            next if name == 'xmlns'
            tree += "\n|#{' ' * indent}#{name}=\"#{value}\""
          end
          for child in childNodes
            tree += child.printTree(indent)
          end
          tree
        end
      end

      class Document < Node
        def self.rxclass
          ::REXML::Document
        end

        def initialize
          super nil
        end

        # ryansking: not sure why this was here. removing it doesn't cause any tests to fail
        # def appendChild node
        #    if node.kind_of? Element and node.name == 'html'
        #      node.rxobj.add_namespace('http://www.w3.org/1999/xhtml')
        #    end
        #    super node
        # end

        def printTree indent=0
          tree = "#document"
          for child in childNodes
            tree += child.printTree(indent + 2)
          end
          return tree
        end
      end

      class DocumentType < Node
        def_delegator :@rxobj, :public, :public_id

        def_delegator :@rxobj, :system, :system_id

        def self.rxclass
          ::REXML::DocType
        end

        def initialize name, public_id, system_id
            super(name)
            if public_id
              @rxobj = ::REXML::DocType.new [name, ::REXML::DocType::PUBLIC, public_id, system_id]
            elsif system_id
              @rxobj = ::REXML::DocType.new [name, ::REXML::DocType::SYSTEM, nil, system_id]
            else
              @rxobj = ::REXML::DocType.new name
            end
        end

        def printTree indent=0
          "\n|#{' ' * indent}<!DOCTYPE #{name}>"
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
        def initialize data
          raw = data.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
          @rxobj = ::REXML::Text.new(raw, true, nil, true)
        end

        def printTree indent=0
          "\n|#{' ' * indent}\"#{rxobj.value}\""
        end
      end

      class CommentNode < Node
        def self.rxclass
          ::REXML::Comment
        end

        def printTree indent=0
          "\n|#{' ' * indent}<!-- #{rxobj.string} -->"
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

        def insertDoctype(name, public_id, system_id)
          doctype = @doctypeClass.new(name, public_id, system_id)
          @document.appendChild(doctype)
        end

        def testSerializer node
          node.printTree
        end

        def get_document
          @document.rxobj
        end

        def get_fragment
          @document = super
          return @document.rxobj.children
        end
      end

    end
  end
end
