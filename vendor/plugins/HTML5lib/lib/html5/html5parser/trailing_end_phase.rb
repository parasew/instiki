require 'html5/html5parser/phase'

module HTML5
  class TrailingEndPhase < Phase

    def process_eof
    end

    def processComment(data)
      @tree.insert_comment(data, @tree.document)
    end

    def processSpaceCharacters(data)
      @parser.last_phase.processSpaceCharacters(data)
    end

    def processCharacters(data)
      parse_error(_('Unexpected non-space characters. Expected end of file.'))
      @parser.phase = @parser.last_phase
      @parser.phase.processCharacters(data)
    end

    def processStartTag(name, attributes)
      parse_error(_('Unexpected start tag (#{name}). Expected end of file.'))
      @parser.phase = @parser.last_phase
      @parser.phase.processStartTag(name, attributes)
    end

    def processEndTag(name)
      parse_error(_('Unexpected end tag (#{name}). Expected end of file.'))
      @parser.phase = @parser.last_phase
      @parser.phase.processEndTag(name)
    end
  end
end