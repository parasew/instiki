module HTML5
  # Base class for helper objects that implement each phase of processing.
  #
  # Handler methods should be in the following order (they can be omitted):
  #
  #   * EOF
  #   * Comment
  #   * Doctype
  #   * SpaceCharacters
  #   * Characters
  #   * StartTag
  #     - startTag* methods
  #   * EndTag
  #     - endTag* methods
  #
  class Phase

    extend Forwardable
    def_delegators :@parser, :parse_error

    # The following example call:
    #
    #   tag_handlers('startTag', 'html', %w( base link meta ), %w( li dt dd ) => 'ListItem')
    #
    # ...would return a hash equal to this:
    #
    #   { 'html' => 'startTagHtml',
    #     'base' => 'startTagBaseLinkMeta',
    #     'link' => 'startTagBaseLinkMeta',
    #     'meta' => 'startTagBaseLinkMeta',
    #     'li'   => 'startTagListItem',
    #     'dt'   => 'startTagListItem',
    #     'dd'   => 'startTagListItem'  }
    #
    def self.tag_handlers(prefix, *tags)
      mapping = {}
      if tags.last.is_a?(Hash)
        tags.pop.each do |names, handler_method_suffix|
          handler_method = prefix + handler_method_suffix
          Array(names).each {|name| mapping[name] = handler_method }
        end
      end
      tags.each do |names|
        names = Array(names)
        handler_method = prefix + names.map {|name| name.capitalize }.join
        names.each {|name| mapping[name] = handler_method }
      end
      mapping
    end

    def self.start_tag_handlers
      @start_tag_handlers ||= Hash.new('startTagOther')
    end

    # Declare what start tags this Phase handles. Can be called more than once.
    #
    # Example usage:
    #
    #   handle_start 'html'
    #   # html start tags will be handled by a method named 'startTagHtml'
    #
    #   handle_start %( base link meta )
    #   # base, link and meta start tags will be handled by a method named 'startTagBaseLinkMeta'
    #
    #   handle_start %( li dt dd ) => 'ListItem'
    #   # li, dt, and dd start tags will be handled by a method named 'startTagListItem'
    #
    def self.handle_start(*tags)
      start_tag_handlers.update tag_handlers('startTag', *tags)
    end

    def self.end_tag_handlers
      @end_tag_handlers ||= Hash.new('endTagOther')
    end

    # Declare what end tags this Phase handles. Behaves like handle_start.
    #
    def self.handle_end(*tags)
      end_tag_handlers.update tag_handlers('endTag', *tags)
    end

    def initialize(parser, tree)
      @parser, @tree = parser, tree
    end

    def process_eof
      @tree.generateImpliedEndTags

      if @tree.open_elements.length > 2
        parse_error("expected-closing-tag-but-got-eof")
      elsif @tree.open_elements.length == 2 and @tree.open_elements[1].name != 'body'
        # This happens for framesets or something?
        parse_error("expected-closing-tag-but-got-eof")
      elsif @parser.inner_html and @tree.open_elements.length > 1 
        # XXX This is not what the specification says. Not sure what to do here.
        parse_error("eof-in-innerhtml")
      end
      # Betting ends.
    end

    def processComment(data)
      # For most phases the following is correct. Where it's not it will be
      # overridden.
      @tree.insert_comment(data, @tree.open_elements.last)
    end

    def processDoctype(name, publicId, systemId, correct)
      parse_error("unexpected-doctype")
    end

    def processSpaceCharacters(data)
      @tree.insertText(data)
    end

    def processStartTag(name, attributes)
      send self.class.start_tag_handlers[name], name, attributes
    end

    def startTagHtml(name, attributes)
      if @parser.first_start_tag == false and name == 'html'
         parse_error("non-html-root")
      end
      # XXX Need a check here to see if the first start tag token emitted is
      # this token... If it's not, invoke parse_error.
      attributes.each do |attr, value|
        unless @tree.open_elements.first.attributes.has_key?(attr)
          @tree.open_elements.first.attributes[attr] = value
        end
      end
      @parser.first_start_tag = false
    end

    def processEndTag(name)
      send self.class.end_tag_handlers[name], name
    end

    def assert(value)
      throw AssertionError.new unless value
    end

    def in_scope?(*args)
      @tree.elementInScope(*args)
    end

    def remove_open_elements_until(name=nil)
      finished = false
      until finished || @tree.open_elements.length == 0
        element = @tree.open_elements.pop
        finished = name.nil? ? yield(element) : element.name == name
      end
      return element
    end
  end
end
