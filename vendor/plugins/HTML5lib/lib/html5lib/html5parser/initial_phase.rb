require 'html5lib/html5parser/phase'

module HTML5lib
  class InitialPhase < Phase

    # This phase deals with error handling as well which is currently not
    # covered in the specification. The error handling is typically known as
    # "quirks mode". It is expected that a future version of HTML5 will define this.

    def processEOF
      @parser.parseError(_('Unexpected End of file. Expected DOCTYPE.'))
      @parser.phase = @parser.phases[:rootElement]
      @parser.phase.processEOF
    end

    def processComment(data)
      @tree.insertComment(data, @tree.document)
    end

    def processDoctype(name, error)
      @parser.parseError(_('Erroneous DOCTYPE.')) if error
      @tree.insertDoctype(name)
      @parser.phase = @parser.phases[:rootElement]
    end

    def processSpaceCharacters(data)
      @tree.insertText(data, @tree.document)
    end

    def processCharacters(data)
      @parser.parseError(_('Unexpected non-space characters. Expected DOCTYPE.'))
      @parser.phase = @parser.phases[:rootElement]
      @parser.phase.processCharacters(data)
    end

    def processStartTag(name, attributes)
      @parser.parseError(_("Unexpected start tag (#{name}). Expected DOCTYPE."))
      @parser.phase = @parser.phases[:rootElement]
      @parser.phase.processStartTag(name, attributes)
    end

    def processEndTag(name)
      @parser.parseError(_("Unexpected end tag (#{name}). Expected DOCTYPE."))
      @parser.phase = @parser.phases[:rootElement]
      @parser.phase.processEndTag(name)
    end

  end
end