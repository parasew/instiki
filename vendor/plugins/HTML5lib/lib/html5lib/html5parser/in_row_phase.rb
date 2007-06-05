require 'html5lib/html5parser/phase'

module HTML5lib
  class InRowPhase < Phase

    # http://www.whatwg.org/specs/web-apps/current-work/#in-row

    handle_start 'html', %w( td th ) => 'TableCell', %w( caption col colgroup tbody tfoot thead tr ) => 'TableOther'

    handle_end 'tr', 'table', %w( tbody tfoot thead ) => 'TableRowGroup', %w( body caption col colgroup html td th ) => 'Ignore'

    def processCharacters(data)
      @parser.phases[:inTable].processCharacters(data)
    end

    def startTagTableCell(name, attributes)
      clearStackToTableRowContext
      @tree.insertElement(name, attributes)
      @parser.phase = @parser.phases[:inCell]
      @tree.activeFormattingElements.push(Marker)
    end

    def startTagTableOther(name, attributes)
      ignoreEndTag = ignoreEndTagTr
      endTagTr('tr')
      # XXX how are we sure it's always ignored in the innerHTML case?
      @parser.phase.processStartTag(name, attributes) unless ignoreEndTag
    end

    def startTagOther(name, attributes)
      @parser.phases[:inTable].processStartTag(name, attributes)
    end

    def endTagTr(name)
      if ignoreEndTagTr
        # innerHTML case
        assert @parser.innerHTML
        @parser.parseError
      else
        clearStackToTableRowContext
        @tree.openElements.pop
        @parser.phase = @parser.phases[:inTableBody]
      end
    end

    def endTagTable(name)
      ignoreEndTag = ignoreEndTagTr
      endTagTr('tr')
      # Reprocess the current tag if the tr end tag was not ignored
      # XXX how are we sure it's always ignored in the innerHTML case?
      @parser.phase.processEndTag(name) unless ignoreEndTag
    end

    def endTagTableRowGroup(name)
      if in_scope?(name, true)
        endTagTr('tr')
        @parser.phase.processEndTag(name)
      else
        # innerHTML case
        @parser.parseError
      end
    end

    def endTagIgnore(name)
      @parser.parseError(_("Unexpected end tag (#{name}) in the row phase. Ignored."))
    end

    def endTagOther(name)
      @parser.phases[:inTable].processEndTag(name)
    end

    protected

    # XXX unify this with other table helper methods
    def clearStackToTableRowContext
      until ['tr', 'html'].include?(name = @tree.openElements[-1].name)
        @parser.parseError(_("Unexpected implied end tag (#{name}) in the row phase."))
        @tree.openElements.pop
      end
    end

    def ignoreEndTagTr
      not in_scope?('tr', :tableVariant => true)
    end

  end
end