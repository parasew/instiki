require 'html5lib/html5parser/phase'

module HTML5lib
  class InFramesetPhase < Phase

    # http://www.whatwg.org/specs/web-apps/current-work/#in-frameset

    handle_start 'html', 'frameset', 'frame', 'noframes'

    handle_end 'frameset', 'noframes'

    def processCharacters(data)
      @parser.parseError(_('Unexpected characters in the frameset phase. Characters ignored.'))
    end

    def startTagFrameset(name, attributes)
      @tree.insertElement(name, attributes)
    end

    def startTagFrame(name, attributes)
      @tree.insertElement(name, attributes)
      @tree.openElements.pop
    end

    def startTagNoframes(name, attributes)
      @parser.phases[:inBody].processStartTag(name, attributes)
    end

    def startTagOther(name, attributes)
      @parser.parseError(_("Unexpected start tag token (#{name}) in the frameset phase. Ignored"))
    end

    def endTagFrameset(name)
      if @tree.openElements[-1].name == 'html'
        # innerHTML case
        @parser.parseError(_("Unexpected end tag token (frameset) in the frameset phase (innerHTML)."))
      else
        @tree.openElements.pop
      end
      if (not @parser.innerHTML and
        @tree.openElements[-1].name != 'frameset')
        # If we're not in innerHTML mode and the the current node is not a
        # "frameset" element (anymore) then switch.
        @parser.phase = @parser.phases[:afterFrameset]
      end
    end

    def endTagNoframes(name)
      @parser.phases[:inBody].processEndTag(name)
    end

    def endTagOther(name)
      @parser.parseError(_("Unexpected end tag token (#{name}) in the frameset phase. Ignored."))
    end

  end
end