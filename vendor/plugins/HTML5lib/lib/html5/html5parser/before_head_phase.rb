require 'html5/html5parser/phase'

module HTML5
  class BeforeHeadPhase < Phase

    handle_start 'html', 'head'

    handle_end %w( html head body br p ) => 'ImplyHead'

    def process_eof
      startTagHead('head', {})
      @parser.phase.process_eof
    end

    def processCharacters(data)
      startTagHead('head', {})
      @parser.phase.processCharacters(data)
    end

    def startTagHead(name, attributes)
      @tree.insert_element(name, attributes)
      @tree.head_pointer = @tree.open_elements[-1]
      @parser.phase = @parser.phases[:inHead]
    end

    def startTagOther(name, attributes)
      startTagHead('head', {})
      @parser.phase.processStartTag(name, attributes)
    end

    def endTagImplyHead(name)
      startTagHead('head', {})
      @parser.phase.processEndTag(name)
    end

    def endTagOther(name)
      parse_error(_("Unexpected end tag (#{name}) after the (implied) root element."))
    end

  end
end
