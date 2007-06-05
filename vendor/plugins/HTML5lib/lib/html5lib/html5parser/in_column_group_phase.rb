require 'html5lib/html5parser/phase'

module HTML5lib
  class InColumnGroupPhase < Phase

    # http://www.whatwg.org/specs/web-apps/current-work/#in-column

    handle_start 'html', 'col'

    handle_end 'colgroup', 'col'

    def ignoreEndTagColgroup
      @tree.openElements[-1].name == 'html'
    end

    def processCharacters(data)
      ignoreEndTag = ignoreEndTagColgroup
      endTagColgroup("colgroup")
      @parser.phase.processCharacters(data) unless ignoreEndTag
    end

    def startTagCol(name, attributes)
      @tree.insertElement(name, attributes)
      @tree.openElements.pop
    end

    def startTagOther(name, attributes)
      ignoreEndTag = ignoreEndTagColgroup
      endTagColgroup('colgroup')
      @parser.phase.processStartTag(name, attributes) unless ignoreEndTag
    end

    def endTagColgroup(name)
      if ignoreEndTagColgroup
        # innerHTML case
        assert @parser.innerHTML
        @parser.parseError
      else
        @tree.openElements.pop
        @parser.phase = @parser.phases[:inTable]
      end
    end

    def endTagCol(name)
      @parser.parseError(_('Unexpected end tag (col). col has no end tag.'))
    end

    def endTagOther(name)
      ignoreEndTag = ignoreEndTagColgroup
      endTagColgroup('colgroup')
      @parser.phase.processEndTag(name) unless ignoreEndTag
    end

  end
end