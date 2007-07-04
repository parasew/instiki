require 'html5/html5parser/phase'

module HTML5
  class TrailingEndPhase < Phase

    def processEOF
    end

    def processComment(data)
      @tree.insertComment(data, @tree.document)
    end

    def processSpaceCharacters(data)
      @parser.lastPhase.processSpaceCharacters(data)
    end

    def processCharacters(data)
      @parser.parseError(_('Unexpected non-space characters. Expected end of file.'))
      @parser.phase = @parser.lastPhase
      @parser.phase.processCharacters(data)
    end

    def processStartTag(name, attributes)
      @parser.parseError(_('Unexpected start tag (#{name}). Expected end of file.'))
      @parser.phase = @parser.lastPhase
      @parser.phase.processStartTag(name, attributes)
    end

    def processEndTag(name)
      @parser.parseError(_('Unexpected end tag (#{name}). Expected end of file.'))
      @parser.phase = @parser.lastPhase
      @parser.phase.processEndTag(name)
    end

  end
end