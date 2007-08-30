require 'html5/html5parser/phase'

module HTML5
  class AfterFramesetPhase < Phase

    # http://www.whatwg.org/specs/web-apps/current-work/#after3

    handle_start 'html', 'noframes'

    handle_end 'html'

    def processCharacters(data)
      parse_error(_('Unexpected non-space characters in the after frameset phase. Ignored.'))
    end

    def startTagNoframes(name, attributes)
      @parser.phases[:inBody].processStartTag(name, attributes)
    end

    def startTagOther(name, attributes)
      parse_error(_("Unexpected start tag (#{name}) in the after frameset phase. Ignored."))
    end

    def endTagHtml(name)
      @parser.last_phase = @parser.phase
      @parser.phase      = @parser.phases[:trailingEnd]
    end

    def endTagOther(name)
      parse_error(_("Unexpected end tag (#{name}) in the after frameset phase. Ignored."))
    end

  end
end