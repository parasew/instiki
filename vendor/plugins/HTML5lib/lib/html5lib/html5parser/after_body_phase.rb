require 'html5lib/html5parser/phase'

module HTML5lib
  class AfterBodyPhase < Phase

    handle_end 'html'

    def processComment(data)
      # This is needed because data is to be appended to the <html> element
      # here and not to whatever is currently open.
      @tree.insertComment(data, @tree.openElements[0])
    end

    def processCharacters(data)
      @parser.parseError(_('Unexpected non-space characters in the after body phase.'))
      @parser.phase = @parser.phases[:inBody]
      @parser.phase.processCharacters(data)
    end

    def processStartTag(name, attributes)
      @parser.parseError(_("Unexpected start tag token (#{name}) in the after body phase."))
      @parser.phase = @parser.phases[:inBody]
      @parser.phase.processStartTag(name, attributes)
    end

    def endTagHtml(name)
      if @parser.innerHTML
        @parser.parseError
      else
        # XXX: This may need to be done, not sure
        # Don't set lastPhase to the current phase but to the inBody phase
        # instead. No need for extra parse errors if there's something after </html>.
        # Try "<!doctype html>X</html>X" for instance.
        @parser.lastPhase = @parser.phase
        @parser.phase = @parser.phases[:trailingEnd]
      end
    end

    def endTagOther(name)
      @parser.parseError(_("Unexpected end tag token (#{name}) in the after body phase."))
      @parser.phase = @parser.phases[:inBody]
      @parser.phase.processEndTag(name)
    end

  end
end