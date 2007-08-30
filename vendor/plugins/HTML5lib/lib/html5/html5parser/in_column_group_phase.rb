require 'html5/html5parser/phase'

module HTML5
  class InColumnGroupPhase < Phase

    # http://www.whatwg.org/specs/web-apps/current-work/#in-column

    handle_start 'html', 'col'

    handle_end 'colgroup', 'col'

    def ignoreEndTagColgroup
      @tree.open_elements[-1].name == 'html'
    end

    def processCharacters(data)
      ignoreEndTag = ignoreEndTagColgroup
      endTagColgroup("colgroup")
      @parser.phase.processCharacters(data) unless ignoreEndTag
    end

    def startTagCol(name, attributes)
      @tree.insert_element(name, attributes)
      @tree.open_elements.pop
    end

    def startTagOther(name, attributes)
      ignoreEndTag = ignoreEndTagColgroup
      endTagColgroup('colgroup')
      @parser.phase.processStartTag(name, attributes) unless ignoreEndTag
    end

    def endTagColgroup(name)
      if ignoreEndTagColgroup
        # inner_html case
        assert @parser.inner_html
        parse_error
      else
        @tree.open_elements.pop
        @parser.phase = @parser.phases[:inTable]
      end
    end

    def endTagCol(name)
      parse_error(_('Unexpected end tag (col). col has no end tag.'))
    end

    def endTagOther(name)
      ignoreEndTag = ignoreEndTagColgroup
      endTagColgroup('colgroup')
      @parser.phase.processEndTag(name) unless ignoreEndTag
    end

  end
end