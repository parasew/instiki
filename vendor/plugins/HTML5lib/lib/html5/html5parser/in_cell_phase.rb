require 'html5/html5parser/phase'

module HTML5
  class InCellPhase < Phase

    # http://www.whatwg.org/specs/web-apps/current-work/#in-cell

    handle_start 'html', %w( caption col colgroup tbody td tfoot th thead tr ) => 'TableOther'

    handle_end %w( td th ) => 'TableCell', %w( body caption col colgroup html ) => 'Ignore'

    handle_end %w( table tbody tfoot thead tr ) => 'Imply'

    def processCharacters(data)
      @parser.phases[:inBody].processCharacters(data)
    end

    def startTagTableOther(name, attributes)
      if in_scope?('td', true) or in_scope?('th', true)
        closeCell
        @parser.phase.processStartTag(name, attributes)
      else
        # inner_html case
        parse_error
      end
    end

    def startTagOther(name, attributes)
      @parser.phases[:inBody].processStartTag(name, attributes)
    end

    def endTagTableCell(name)
      if in_scope?(name, true)
        @tree.generateImpliedEndTags(name)
        if @tree.open_elements.last.name != name
          parse_error("Got table cell end tag (#{name}) while required end tags are missing.")

          remove_open_elements_until(name)
        else
          @tree.open_elements.pop
        end
        @tree.clearActiveFormattingElements
        @parser.phase = @parser.phases[:inRow]
      else
        parse_error(_("Unexpected end tag (#{name}). Ignored."))
      end
    end

    def endTagIgnore(name)
      parse_error(_("Unexpected end tag (#{name}). Ignored."))
    end

    def endTagImply(name)
      if in_scope?(name, true)
        closeCell
        @parser.phase.processEndTag(name)
      else
        # sometimes inner_html case
        parse_error
      end
    end

    def endTagOther(name)
      @parser.phases[:inBody].processEndTag(name)
    end

    protected

    def closeCell
      if in_scope?('td', true)
        endTagTableCell('td')
      elsif in_scope?('th', true)
        endTagTableCell('th')
      end
    end

  end
end