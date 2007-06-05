require 'html5lib/html5parser/phase'

module HTML5lib
  class BeforeHeadPhase < Phase

    handle_start 'html', 'head'

    handle_end 'html'

    def processEOF
      startTagHead('head', {})
      @parser.phase.processEOF
    end

    def processCharacters(data)
      startTagHead('head', {})
      @parser.phase.processCharacters(data)
    end

    def startTagHead(name, attributes)
      @tree.insertElement(name, attributes)
      @tree.headPointer = @tree.openElements[-1]
      @parser.phase = @parser.phases[:inHead]
    end

    def startTagOther(name, attributes)
      startTagHead('head', {})
      @parser.phase.processStartTag(name, attributes)
    end

    def endTagHtml(name)
      startTagHead('head', {})
      @parser.phase.processEndTag(name)
    end

    def endTagOther(name)
      @parser.parseError(_("Unexpected end tag (#{name}) after the (implied) root element."))
    end

  end
end