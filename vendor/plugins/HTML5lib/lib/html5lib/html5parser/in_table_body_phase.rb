require 'html5lib/html5parser/phase'

module HTML5lib
  class InTableBodyPhase < Phase

    # http://www.whatwg.org/specs/web-apps/current-work/#in-table0

    handle_start 'html', 'tr', %w( td th ) => 'TableCell', %w( caption col colgroup tbody tfoot thead ) => 'TableOther'

    handle_end 'table', %w( tbody tfoot thead ) => 'TableRowGroup', %w( body caption col colgroup html td th tr ) => 'Ingore'

    def processCharacters(data)
      @parser.phases[:inTable].processCharacters(data)
    end

    def startTagTr(name, attributes)
      clearStackToTableBodyContext
      @tree.insertElement(name, attributes)
      @parser.phase = @parser.phases[:inRow]
    end

    def startTagTableCell(name, attributes)
      @parser.parseError(_("Unexpected table cell start tag (#{name}) in the table body phase."))
      startTagTr('tr', {})
      @parser.phase.processStartTag(name, attributes)
    end

    def startTagTableOther(name, attributes)
      # XXX AT Any ideas on how to share this with endTagTable?
      if in_scope?('tbody', true) or in_scope?('thead', true) or in_scope?('tfoot', true)
        clearStackToTableBodyContext
        endTagTableRowGroup(@tree.openElements[-1].name)
        @parser.phase.processStartTag(name, attributes)
      else
        # innerHTML case
        @parser.parseError
      end
    end

    def startTagOther(name, attributes)
      @parser.phases[:inTable].processStartTag(name, attributes)
    end

    def endTagTableRowGroup(name)
      if in_scope?(name, true)
        clearStackToTableBodyContext
        @tree.openElements.pop
        @parser.phase = @parser.phases[:inTable]
      else
        @parser.parseError(_("Unexpected end tag (#{name}) in the table body phase. Ignored."))
      end
    end

    def endTagTable(name)
      if in_scope?('tbody', true) or in_scope?('thead', true) or in_scope?('tfoot', true)
        clearStackToTableBodyContext
        endTagTableRowGroup(@tree.openElements[-1].name)
        @parser.phase.processEndTag(name)
      else
        # innerHTML case
        @parser.parseError
      end
    end

    def endTagIgnore(name)
      @parser.parseError(_("Unexpected end tag (#{name}) in the table body phase. Ignored."))
    end

    def endTagOther(name)
      @parser.phases[:inTable].processEndTag(name)
    end

    protected

    def clearStackToTableBodyContext
      until ['tbody', 'tfoot', 'thead', 'html'].include?(name = @tree.openElements[-1].name)
        @parser.parseError(_("Unexpected implied end tag (#{name}) in the table body phase."))
        @tree.openElements.pop
      end
    end

  end
end