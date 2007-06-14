require 'html5lib/constants'
module HTML5lib
module TreeWalkers

module TokenConstructor
    def error(msg)
        return {:type => "SerializeError", :data => msg}
    end

    def normalizeAttrs(attrs)
        attrs.to_a
    end

    def emptyTag(name, attrs, hasChildren=false)
        error(_("Void element has children")) if hasChildren
        return({:type => :EmptyTag, :name => name, \
                :data => normalizeAttrs(attrs)})
    end

    def startTag(name, attrs)
        return {:type => :StartTag, :name => name, \
                 :data => normalizeAttrs(attrs)}
    end

    def endTag(name)
        return {:type => :EndTag, :name => name, :data => []}
    end

    def text(data)
        if data =~ /\A([#{SPACE_CHARACTERS.join('')}]+)/m
          yield({:type => :SpaceCharacters, :data => $1})
          data = data[$1.length .. -1]
          return if data.empty?
        end

        if data =~ /([#{SPACE_CHARACTERS.join('')}]+)\Z/m
          yield({:type => :Characters, :data => data[0 ... -$1.length]})
          yield({:type => :SpaceCharacters, :data => $1})
        else
          yield({:type => :Characters, :data => data})
        end
    end

    def comment(data)
        return {:type => :Comment, :data => data}
    end

    def doctype(name)
        return {:type => :Doctype, :name => name, :data => name.upcase() == "HTML"}
    end

    def unknown(nodeType)
        return error(_("Unknown node type: ") + nodeType.to_s)
    end

    def _(str)
      str
    end
end

class Base
    include TokenConstructor

    def initialize(tree)
        @tree = tree
    end

    def each
        raise NotImplementedError
    end

    alias walk each
end

class NonRecursiveTreeWalker < TreeWalkers::Base
    def node_details(node)
        raise NotImplementedError
    end

    def first_child(node)
        raise NotImplementedError
    end

    def next_sibling(node)
        raise NotImplementedError
    end

    def parent(node)
        raise NotImplementedError
    end

    def each
        currentNode = @tree
        while currentNode != nil
            details = node_details(currentNode)
            hasChildren = false

            case details.shift
            when :DOCTYPE
                yield doctype(*details)

            when :TEXT
                text(*details) {|token| yield token}

            when :ELEMENT
                name, attributes, hasChildren = details
                if VOID_ELEMENTS.include?(name)
                    yield emptyTag(name, attributes.to_a, hasChildren)
                    hasChildren = false
                else
                    yield startTag(name, attributes.to_a)
                end

            when :COMMENT
                yield comment(details[0])

            when :DOCUMENT, :DOCUMENT_FRAGMENT
                hasChildren = true

            when nil
                # ignore (REXML::XMLDecl is an example)

            else
                yield unknown(details[0])
            end

            firstChild = hasChildren ? first_child(currentNode) : nil
            if firstChild != nil
                currentNode = firstChild
            else
                while currentNode != nil
                    details = node_details(currentNode)
                    if details.shift == :ELEMENT
                        name, attributes, hasChildren = details
                        yield endTag(name) if !VOID_ELEMENTS.include?(name)
                    end

                    if @tree == currentNode
                        currentNode = nil
                    else
                        nextSibling = next_sibling(currentNode)
                        if nextSibling != nil
                            currentNode = nextSibling
                            break
                        end

                        currentNode = parent(currentNode)
                    end
                end
            end
        end
    end
end

end
end
