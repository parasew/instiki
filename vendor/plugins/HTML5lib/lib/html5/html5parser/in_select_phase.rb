require 'html5/html5parser/phase'

module HTML5
  class InSelectPhase < Phase

    # http://www.whatwg.org/specs/web-apps/current-work/#in-select

    handle_start 'html', 'option', 'optgroup', 'select'

    handle_end 'option', 'optgroup', 'select', %w( caption table tbody tfoot thead tr td th ) => 'TableElements'

    def processCharacters(data)
      @tree.insertText(data)
    end

    def startTagOption(name, attributes)
      # We need to imply </option> if <option> is the current node.
      @tree.open_elements.pop if @tree.open_elements.last.name == 'option'
      @tree.insert_element(name, attributes)
    end

    def startTagOptgroup(name, attributes)
      @tree.open_elements.pop if @tree.open_elements.last.name == 'option'
      @tree.open_elements.pop if @tree.open_elements.last.name == 'optgroup'
      @tree.insert_element(name, attributes)
    end

    def startTagSelect(name, attributes)
      parse_error(_('Unexpected start tag (select) in the select phase implies select start tag.'))
      endTagSelect('select')
    end

    def startTagOther(name, attributes)
      parse_error(_('Unexpected start tag token (#{name}) in the select phase. Ignored.'))
    end

    def endTagOption(name)
      if @tree.open_elements.last.name == 'option'
        @tree.open_elements.pop
      else
        parse_error(_('Unexpected end tag (option) in the select phase. Ignored.'))
      end
    end

    def endTagOptgroup(name)
      # </optgroup> implicitly closes <option>
      if @tree.open_elements.last.name == 'option' and @tree.open_elements[-2].name == 'optgroup'
        @tree.open_elements.pop
      end
      # It also closes </optgroup>
      if @tree.open_elements.last.name == 'optgroup'
        @tree.open_elements.pop
      # But nothing else
      else
        parse_error(_('Unexpected end tag (optgroup) in the select phase. Ignored.'))
      end
    end

    def endTagSelect(name)
      if in_scope?('select', true)
        remove_open_elements_until('select')

        @parser.reset_insertion_mode
      else
        # inner_html case
        parse_error
      end
    end

    def endTagTableElements(name)
      parse_error(_("Unexpected table end tag (#{name}) in the select phase."))

      if in_scope?(name, true)
        endTagSelect('select')
        @parser.phase.processEndTag(name)
      end
    end

    def endTagOther(name)
      parse_error(_("Unexpected end tag token (#{name}) in the select phase. Ignored."))
    end

  end
end