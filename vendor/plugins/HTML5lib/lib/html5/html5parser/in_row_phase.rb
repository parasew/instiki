require 'html5/html5parser/phase'

module HTML5
  class InRowPhase < Phase

    # http://www.whatwg.org/specs/web-apps/current-work/#in-row

    handle_start 'html', %w( td th ) => 'TableCell', %w( caption col colgroup tbody tfoot thead tr ) => 'TableOther'

    handle_end 'tr', 'table', %w( tbody tfoot thead ) => 'TableRowGroup', %w( body caption col colgroup html td th ) => 'Ignore'

    def processCharacters(data)
      @parser.phases[:inTable].processCharacters(data)
    end

    def startTagTableCell(name, attributes)
      clearStackToTableRowContext
      @tree.insert_element(name, attributes)
      @parser.phase = @parser.phases[:inCell]
      @tree.activeFormattingElements.push(Marker)
    end

    def startTagTableOther(name, attributes)
      ignoreEndTag = ignoreEndTagTr
      endTagTr('tr')
      # XXX how are we sure it's always ignored in the inner_html case?
      @parser.phase.processStartTag(name, attributes) unless ignoreEndTag
    end

    def startTagOther(name, attributes)
      @parser.phases[:inTable].processStartTag(name, attributes)
    end

    def endTagTr(name)
      if ignoreEndTagTr
        # inner_html case
        assert @parser.inner_html
        parse_error
      else
        clearStackToTableRowContext
        @tree.open_elements.pop
        @parser.phase = @parser.phases[:inTableBody]
      end
    end

    def endTagTable(name)
      ignoreEndTag = ignoreEndTagTr
      endTagTr('tr')
      # Reprocess the current tag if the tr end tag was not ignored
      # XXX how are we sure it's always ignored in the inner_html case?
      @parser.phase.processEndTag(name) unless ignoreEndTag
    end

    def endTagTableRowGroup(name)
      if in_scope?(name, true)
        endTagTr('tr')
        @parser.phase.processEndTag(name)
      else
        # inner_html case
        parse_error
      end
    end

    def endTagIgnore(name)
      parse_error("unexpected-end-tag-in-table-row",
              {"name" => name})
    end

    def endTagOther(name)
      @parser.phases[:inTable].processEndTag(name)
    end

    protected

    # XXX unify this with other table helper methods
    def clearStackToTableRowContext
      until %w[tr html].include?(name = @tree.open_elements.last.name)
        parse_error("unexpected-implied-end-tag-in-table-row",
                {"name" => @tree.open_elements.last.name})
        @tree.open_elements.pop
      end
    end

    def ignoreEndTagTr
      not in_scope?('tr', :tableVariant => true)
    end

  end
end