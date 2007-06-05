require 'html5lib/html5parser/phase'

module HTML5lib
  class InTablePhase < Phase

    # http://www.whatwg.org/specs/web-apps/current-work/#in-table

    handle_start 'html', 'caption', 'colgroup', 'col', 'table'

    handle_start %w( tbody tfoot thead ) => 'RowGroup', %w( td th tr ) => 'ImplyTbody'

    handle_end 'table', %w( body caption col colgroup html tbody td tfoot th thead tr ) => 'Ignore'

    def processCharacters(data)
      @parser.parseError(_("Unexpected non-space characters in table context caused voodoo mode."))
      # Make all the special element rearranging voodoo kick in
      @tree.insertFromTable = true
      # Process the character in the "in body" mode
      @parser.phases[:inBody].processCharacters(data)
      @tree.insertFromTable = false
    end

    def startTagCaption(name, attributes)
      clearStackToTableContext
      @tree.activeFormattingElements.push(Marker)
      @tree.insertElement(name, attributes)
      @parser.phase = @parser.phases[:inCaption]
    end

    def startTagColgroup(name, attributes)
      clearStackToTableContext
      @tree.insertElement(name, attributes)
      @parser.phase = @parser.phases[:inColumnGroup]
    end

    def startTagCol(name, attributes)
      startTagColgroup('colgroup', {})
      @parser.phase.processStartTag(name, attributes)
    end

    def startTagRowGroup(name, attributes)
      clearStackToTableContext
      @tree.insertElement(name, attributes)
      @parser.phase = @parser.phases[:inTableBody]
    end

    def startTagImplyTbody(name, attributes)
      startTagRowGroup('tbody', {})
      @parser.phase.processStartTag(name, attributes)
    end

    def startTagTable(name, attributes)
      @parser.parseError(_("Unexpected start tag (table) in table phase. Implies end tag (table)."))
      @parser.phase.processEndTag('table')
      @parser.phase.processStartTag(name, attributes) unless @parser.innerHTML
    end

    def startTagOther(name, attributes)
      @parser.parseError(_("Unexpected start tag (#{name}) in table context caused voodoo mode."))
      # Make all the special element rearranging voodoo kick in
      @tree.insertFromTable = true
      # Process the start tag in the "in body" mode
      @parser.phases[:inBody].processStartTag(name, attributes)
      @tree.insertFromTable = false
    end

    def endTagTable(name)
      if in_scope?('table', true)
        @tree.generateImpliedEndTags
      
        unless @tree.openElements[-1].name == 'table'
          @parser.parseError(_("Unexpected end tag (table). Expected end tag (#{@tree.openElements[-1].name})."))
        end
      
        remove_open_elements_until('table')

        @parser.resetInsertionMode
      else
        # innerHTML case
        assert @parser.innerHTML
        @parser.parseError
      end
    end

    def endTagIgnore(name)
      @parser.parseError(_("Unexpected end tag (#{name}). Ignored."))
    end

    def endTagOther(name)
      @parser.parseError(_("Unexpected end tag (#{name}) in table context caused voodoo mode."))
      # Make all the special element rearranging voodoo kick in
      @parser.insertFromTable = true
      # Process the end tag in the "in body" mode
      @parser.phases[:inBody].processEndTag(name)
      @parser.insertFromTable = false
    end

    protected

    def clearStackToTableContext
      # "clear the stack back to a table context"
      until ['table', 'html'].include?(name = @tree.openElements[-1].name)
        @parser.parseError(_("Unexpected implied end tag (#{name}) in the table phase."))
        @tree.openElements.pop
      end
      # When the current node is <html> it's an innerHTML case
    end

  end
end