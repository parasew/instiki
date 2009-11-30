require 'html5/html5parser/phase'

module HTML5
  class AfterHeadPhase < Phase

    handle_start 'html', 'body', 'frameset', %w( base link meta script style title ) => 'FromHead'

    def process_eof
      anything_else
      @parser.phase.process_eof
    end

    def processCharacters(data)
      anything_else
      @parser.phase.processCharacters(data)
    end

    def startTagBody(name, attributes)
      @tree.insert_element(name, attributes)
      @parser.phase = @parser.phases[:inBody]
    end

    def startTagFrameset(name, attributes)
      @tree.insert_element(name, attributes)
      @parser.phase = @parser.phases[:inFrameset]
    end

    def startTagFromHead(name, attributes)
      parse_error("unexpected-start-tag-out-of-my-head", {"name" => name})
      @parser.phase = @parser.phases[:inHead]
      @parser.phase.processStartTag(name, attributes)
    end

    def startTagOther(name, attributes)
      anything_else
      @parser.phase.processStartTag(name, attributes)
    end

    def processEndTag(name)
      anything_else
      @parser.phase.processEndTag(name)
    end

    def anything_else
      @tree.insert_element('body', {})
      @parser.phase = @parser.phases[:inBody]
    end

  end
end