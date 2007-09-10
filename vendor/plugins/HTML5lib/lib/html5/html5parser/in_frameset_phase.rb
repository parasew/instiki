require 'html5/html5parser/phase'

module HTML5
  class InFramesetPhase < Phase

    # http://www.whatwg.org/specs/web-apps/current-work/#in-frameset

    handle_start 'html', 'frameset', 'frame', 'noframes'

    handle_end 'frameset', 'noframes'

    def processCharacters(data)
      parse_error("unexpected-char-in-frameset")
    end

    def startTagFrameset(name, attributes)
      @tree.insert_element(name, attributes)
    end

    def startTagFrame(name, attributes)
      @tree.insert_element(name, attributes)
      @tree.open_elements.pop
    end

    def startTagNoframes(name, attributes)
      @parser.phases[:inBody].processStartTag(name, attributes)
    end

    def startTagOther(name, attributes)
      parse_error("unexpected-start-tag-in-frameset",
            {"name" => name})
    end

    def endTagFrameset(name)
      if @tree.open_elements.last.name == 'html'
        # inner_html case
        parse_error("unexpected-frameset-in-frameset-innerhtml")
      else
        @tree.open_elements.pop
      end
      if (not @parser.inner_html and
        @tree.open_elements.last.name != 'frameset')
        # If we're not in inner_html mode and the the current node is not a
        # "frameset" element (anymore) then switch.
        @parser.phase = @parser.phases[:afterFrameset]
      end
    end

    def endTagNoframes(name)
      @parser.phases[:inBody].processEndTag(name)
    end

    def endTagOther(name)
      parse_error("unexpected-end-tag-in-frameset", {"name" => name})
    end
  end
end