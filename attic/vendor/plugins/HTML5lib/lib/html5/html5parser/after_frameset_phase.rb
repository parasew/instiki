require 'html5/html5parser/phase'

module HTML5
  class AfterFramesetPhase < Phase

    # http://www.whatwg.org/specs/web-apps/current-work/#after3

    handle_start 'html', 'noframes'

    handle_end 'html'

    def processCharacters(data)
      parse_error("unexpected-char-after-frameset")
    end

    def startTagNoframes(name, attributes)
      @parser.phases[:inBody].processStartTag(name, attributes)
    end

    def startTagOther(name, attributes)
      parse_error("unexpected-start-tag-after-frameset", {"name" => name})
    end

    def endTagHtml(name)
      @parser.last_phase = @parser.phase
      @parser.phase      = @parser.phases[:trailingEnd]
    end

    def endTagOther(name)
      parse_error("unexpected-end-tag-after-frameset", {"name" => name})
    end
  end
end