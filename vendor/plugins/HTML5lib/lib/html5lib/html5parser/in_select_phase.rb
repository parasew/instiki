require 'html5lib/html5parser/phase'

module HTML5lib
  class InSelectPhase < Phase

    # http://www.whatwg.org/specs/web-apps/current-work/#in-select

    handle_start 'html', 'option', 'optgroup', 'select'

    handle_end 'option', 'optgroup', 'select', %w( caption table tbody tfoot thead tr td th ) => 'TableElements'

    def processCharacters(data)
      @tree.insertText(data)
    end

    def startTagOption(name, attributes)
      # We need to imply </option> if <option> is the current node.
      @tree.openElements.pop if @tree.openElements[-1].name == 'option'
      @tree.insertElement(name, attributes)
    end

    def startTagOptgroup(name, attributes)
      @tree.openElements.pop if @tree.openElements[-1].name == 'option'
      @tree.openElements.pop if @tree.openElements[-1].name == 'optgroup'
      @tree.insertElement(name, attributes)
    end

    def startTagSelect(name, attributes)
      @parser.parseError(_('Unexpected start tag (select) in the select phase implies select start tag.'))
      endTagSelect('select')
    end

    def startTagOther(name, attributes)
      @parser.parseError(_('Unexpected start tag token (#{name}) in the select phase. Ignored.'))
    end

    def endTagOption(name)
      if @tree.openElements[-1].name == 'option'
        @tree.openElements.pop
      else
        @parser.parseError(_('Unexpected end tag (option) in the select phase. Ignored.'))
      end
    end

    def endTagOptgroup(name)
      # </optgroup> implicitly closes <option>
      if @tree.openElements[-1].name == 'option' and @tree.openElements[-2].name == 'optgroup'
        @tree.openElements.pop
      end
      # It also closes </optgroup>
      if @tree.openElements[-1].name == 'optgroup'
        @tree.openElements.pop
      # But nothing else
      else
        @parser.parseError(_('Unexpected end tag (optgroup) in the select phase. Ignored.'))
      end
    end

    def endTagSelect(name)
      if in_scope?('select', true)
        remove_open_elements_until('select')

        @parser.resetInsertionMode
      else
        # innerHTML case
        @parser.parseError
      end
    end

    def endTagTableElements(name)
      @parser.parseError(_("Unexpected table end tag (#{name}) in the select phase."))

      if in_scope?(name, true)
        endTagSelect('select')
        @parser.phase.processEndTag(name)
      end
    end

    def endTagOther(name)
      @parser.parseError(_("Unexpected end tag token (#{name}) in the select phase. Ignored."))
    end

  end
end