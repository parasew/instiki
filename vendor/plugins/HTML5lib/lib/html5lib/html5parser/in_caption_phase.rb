require 'html5lib/html5parser/phase'

module HTML5lib
  class InCaptionPhase < Phase

    # http://www.whatwg.org/specs/web-apps/current-work/#in-caption

    handle_start 'html', %w( caption col colgroup tbody td tfoot th thead tr ) => 'TableElement'

    handle_end 'caption', 'table', %w( body col colgroup html tbody td tfoot th thead tr ) => 'Ignore'

    def ignoreEndTagCaption
      not in_scope?('caption', true)
    end

    def processCharacters(data)
      @parser.phases[:inBody].processCharacters(data)
    end

    def startTagTableElement(name, attributes)
      @parser.parseError
      #XXX Have to duplicate logic here to find out if the tag is ignored
      ignoreEndTag = ignoreEndTagCaption
      @parser.phase.processEndTag('caption')
      @parser.phase.processStartTag(name, attributes) unless ignoreEndTag
    end

    def startTagOther(name, attributes)
      @parser.phases[:inBody].processStartTag(name, attributes)
    end

    def endTagCaption(name)
      if ignoreEndTagCaption
        # innerHTML case
        assert @parser.innerHTML
        @parser.parseError
      else
        # AT this code is quite similar to endTagTable in "InTable"
        @tree.generateImpliedEndTags

        unless @tree.openElements[-1].name == 'caption'
          @parser.parseError(_("Unexpected end tag (caption). Missing end tags."))
        end

        remove_open_elements_until('caption')

        @tree.clearActiveFormattingElements
        @parser.phase = @parser.phases[:inTable]
      end
    end

    def endTagTable(name)
      @parser.parseError
      ignoreEndTag = ignoreEndTagCaption
      @parser.phase.processEndTag('caption')
      @parser.phase.processEndTag(name) unless ignoreEndTag
    end

    def endTagIgnore(name)
      @parser.parseError(_("Unexpected end tag (#{name}). Ignored."))
    end

    def endTagOther(name)
      @parser.phases[:inBody].processEndTag(name)
    end

  end
end