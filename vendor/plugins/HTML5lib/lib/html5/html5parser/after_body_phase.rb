require 'html5/html5parser/phase'

module HTML5
  class AfterBodyPhase < Phase

    handle_end 'html'

    def processComment(data)
      # This is needed because data is to be appended to the <html> element
      # here and not to whatever is currently open.
      @tree.insert_comment(data, @tree.open_elements.first)
    end

    def processCharacters(data)
      parse_error(_('Unexpected non-space characters in the after body phase.'))
      @parser.phase = @parser.phases[:inBody]
      @parser.phase.processCharacters(data)
    end

    def processStartTag(name, attributes)
      parse_error(_("Unexpected start tag token (#{name}) in the after body phase."))
      @parser.phase = @parser.phases[:inBody]
      @parser.phase.processStartTag(name, attributes)
    end

    def endTagHtml(name)
      if @parser.inner_html
        parse_error
      else
        # XXX: This may need to be done, not sure
        # Don't set last_phase to the current phase but to the inBody phase
        # instead. No need for extra parse errors if there's something after </html>.
        # Try "<!doctype html>X</html>X" for instance.
        @parser.last_phase = @parser.phase
        @parser.phase      = @parser.phases[:trailingEnd]
      end
    end

    def endTagOther(name)
      parse_error(_("Unexpected end tag token (#{name}) in the after body phase."))
      @parser.phase = @parser.phases[:inBody]
      @parser.phase.processEndTag(name)
    end

  end
end