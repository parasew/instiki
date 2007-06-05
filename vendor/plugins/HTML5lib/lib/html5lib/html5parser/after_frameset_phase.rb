require 'html5lib/html5parser/phase'

module HTML5lib
  class AfterFramesetPhase < Phase

    # http://www.whatwg.org/specs/web-apps/current-work/#after3

    handle_start 'html', 'noframes'

    handle_end 'html'

    def processCharacters(data)
      @parser.parseError(_('Unexpected non-space characters in the after frameset phase. Ignored.'))
    end

    def startTagNoframes(name, attributes)
      @parser.phases[:inBody].processStartTag(name, attributes)
    end

    def startTagOther(name, attributes)
      @parser.parseError(_("Unexpected start tag (#{name}) in the after frameset phase. Ignored."))
    end

    def endTagHtml(name)
      @parser.lastPhase = @parser.phase
      @parser.phase = @parser.phases[:trailingEnd]
    end

    def endTagOther(name)
      @parser.parseError(_("Unexpected end tag (#{name}) in the after frameset phase. Ignored."))
    end

  end
end