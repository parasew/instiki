require 'html5/html5parser/phase'

module HTML5
  class InCaptionPhase < Phase

    # http://www.whatwg.org/specs/web-apps/current-work/#in-caption

    handle_start 'html', %w(caption col colgroup tbody td tfoot th thead tr) => 'TableElement'

    handle_end 'caption', 'table', %w(body col colgroup html tbody td tfoot th thead tr) => 'Ignore'

    def ignoreEndTagCaption
      !in_scope?('caption', true)
    end

    def processCharacters(data)
      @parser.phases[:inBody].processCharacters(data)
    end

    def startTagTableElement(name, attributes)
      parse_error "unexpected-end-tag", {"name" => name}
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
        # inner_html case
        assert @parser.inner_html
        parse_error "unexpected-end-tag", {"name" => name}
      else
        # AT this code is quite similar to endTagTable in "InTable"
        @tree.generateImpliedEndTags

        unless @tree.open_elements[-1].name == 'caption'
          parse_error("expected-one-end-tag-but-got-another",
                    {"gotName" => "caption",
                     "expectedName" => @tree.open_elements.last.name})
        end

        remove_open_elements_until('caption')

        @tree.clearActiveFormattingElements
        @parser.phase = @parser.phases[:inTable]
      end
    end

    def endTagTable(name)
      parse_error "unexpected-end-table-in-caption"
      ignoreEndTag = ignoreEndTagCaption
      @parser.phase.processEndTag('caption')
      @parser.phase.processEndTag(name) unless ignoreEndTag
    end

    def endTagIgnore(name)
      parse_error("unexpected-end-tag", {"name" => name})
    end

    def endTagOther(name)
      @parser.phases[:inBody].processEndTag(name)
    end
  end
end