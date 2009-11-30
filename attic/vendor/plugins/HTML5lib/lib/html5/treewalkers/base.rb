require 'html5/constants'
module HTML5
module TreeWalkers

module TokenConstructor
  def error(msg)
    {:type => "SerializeError", :data => msg}
  end

  def normalize_attrs(attrs)
    attrs.to_a
  end

  def empty_tag(name, attrs, has_children=false)
    error(_("Void element has children")) if has_children
    {:type => :EmptyTag, :name => name, :data => normalize_attrs(attrs)}
  end

  def start_tag(name, attrs)
    {:type => :StartTag, :name => name, :data => normalize_attrs(attrs)}
  end

  def end_tag(name)
    {:type => :EndTag, :name => name, :data => []}
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
    {:type => :Comment, :data => data}
  end

  def doctype(name, public_id, system_id, correct=nil)
    {:type => :Doctype, :name => name, :public_id => public_id, :system_id => system_id, :correct => correct}
  end

  def unknown(nodeType)
    error(_("Unknown node type: ") + nodeType.to_s)
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

    def to_ary
      a = []
      each do |i|
        a << i
      end
      a
    end
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
    current_node = @tree
    while current_node != nil
      details = node_details(current_node)
      has_children = false

      case details.shift
      when :DOCTYPE
        yield doctype(*details)

      when :TEXT
        text(*details) {|token| yield token}

      when :ELEMENT
        name, attributes, has_children = details
        if VOID_ELEMENTS.include?(name)
          yield empty_tag(name, attributes.to_a, has_children)
          has_children = false
        else
          yield start_tag(name, attributes.to_a)
        end

      when :COMMENT
        yield comment(details[0])

      when :DOCUMENT, :DOCUMENT_FRAGMENT
        has_children = true

      when nil
        # ignore (REXML::XMLDecl is an example)

      else
        yield unknown(details[0])
      end

      first_child = has_children ? first_child(current_node) : nil
      if first_child != nil
        current_node = first_child
      else
        while current_node != nil
          details = node_details(current_node)
          if details.shift == :ELEMENT
            name, attributes, has_children = details
            yield end_tag(name) if !VOID_ELEMENTS.include?(name)
          end

          if @tree == current_node
            current_node = nil
          else
            next_sibling = next_sibling(current_node)
            if next_sibling != nil
              current_node = next_sibling
              break
            end

            current_node = parent(current_node)
          end
        end
      end
    end
  end
end

end
end
