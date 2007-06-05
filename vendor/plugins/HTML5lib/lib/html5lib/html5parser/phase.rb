module HTML5lib
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

    # The following example call:
    #
    #   tag_handlers('startTag', 'html', %( base link meta ), %( li dt dd ) => 'ListItem')
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
          Array(names).each { |name| mapping[name] = handler_method }
        end
      end
      tags.each do |names|
        names = Array(names)
        handler_method = prefix + names.map { |name| name.capitalize }.join
        names.each { |name| mapping[name] = handler_method }
      end
      return mapping
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

    def processEOF
      @tree.generateImpliedEndTags

      if @tree.openElements.length > 2
        @parser.parseError(_('Unexpected end of file. Missing closing tags.'))
      elsif @tree.openElements.length == 2 and @tree.openElements[1].name != 'body'
        # This happens for framesets or something?
        @parser.parseError(_("Unexpected end of file. Expected end tag (#{@tree.openElements[1].name}) first."))
      elsif @parser.innerHTML and @tree.openElements.length > 1 
        # XXX This is not what the specification says. Not sure what to do here.
        @parser.parseError(_('XXX innerHTML EOF'))
      end
      # Betting ends.
    end

    def processComment(data)
      # For most phases the following is correct. Where it's not it will be
      # overridden.
      @tree.insertComment(data, @tree.openElements[-1])
    end

    def processDoctype(name, error)
      @parser.parseError(_('Unexpected DOCTYPE. Ignored.'))
    end

    def processSpaceCharacters(data)
      @tree.insertText(data)
    end

    def processStartTag(name, attributes)
      send self.class.start_tag_handlers[name], name, attributes
    end

    def startTagHtml(name, attributes)
      if @parser.firstStartTag == false and name == 'html'
         @parser.parseError(_('html needs to be the first start tag.'))
      end
      # XXX Need a check here to see if the first start tag token emitted is
      # this token... If it's not, invoke @parser.parseError.
      attributes.each do |attr, value|
        unless @tree.openElements[0].attributes.has_key?(attr)
          @tree.openElements[0].attributes[attr] = value
        end
      end
      @parser.firstStartTag = false
    end

    def processEndTag(name)
      send self.class.end_tag_handlers[name], name
    end

    def _(string)
      string
    end

    def assert(value)
      throw AssertionError.new unless value
    end

    def in_scope?(*args)
      @tree.elementInScope(*args)
    end

    def remove_open_elements_until(name=nil)
      finished = false
      until finished
        element = @tree.openElements.pop
        finished = name.nil?? yield(element) : element.name == name
      end
      return element
    end

  end
end
