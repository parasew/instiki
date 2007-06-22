require 'html5lib/html5parser/phase'

module HTML5lib
  class InHeadPhase < Phase

    handle_start 'html', 'head', 'title', 'style', 'script', %w( base link meta )

    handle_end 'head'
    handle_end %w( html body br ) => 'ImplyAfterHead'
    handle_end %w( title style script )

    def processEOF
      if ['title', 'style', 'script'].include?(name = @tree.openElements[-1].name)
        @parser.parseError(_("Unexpected end of file. Expected end tag (#{name})."))
        @tree.openElements.pop
      end
      anythingElse
      @parser.phase.processEOF
    end

    def processCharacters(data)
      if ['title', 'style', 'script'].include?(@tree.openElements[-1].name)
        @tree.insertText(data)
      else
        anythingElse
        @parser.phase.processCharacters(data)
      end
    end

    def startTagHead(name, attributes)
      @parser.parseError(_('Unexpected start tag head in existing head. Ignored'))
    end

    def startTagTitle(name, attributes)
      element = @tree.createElement(name, attributes)
      appendToHead(element)
      @tree.openElements.push(element)
      @parser.tokenizer.contentModelFlag = :RCDATA
    end

    def startTagStyle(name, attributes)
      element = @tree.createElement(name, attributes)
      if @tree.headPointer != nil and @parser.phase == @parser.phases[:inHead]
        appendToHead(element)
      else
        @tree.openElements[-1].appendChild(element)
      end
      @tree.openElements.push(element)
      @parser.tokenizer.contentModelFlag = :CDATA
    end

    def startTagScript(name, attributes)
      #XXX Inner HTML case may be wrong
      element = @tree.createElement(name, attributes)
      element._flags.push("parser-inserted")
      if (@tree.headPointer != nil and
        @parser.phase == @parser.phases[:inHead])
        appendToHead(element)
      else
        @tree.openElements[-1].appendChild(element)
      end
      @tree.openElements.push(element)
      @parser.tokenizer.contentModelFlag = :CDATA
    end

    def startTagBaseLinkMeta(name, attributes)
      element = @tree.createElement(name, attributes)
      if @tree.headPointer != nil and @parser.phase == @parser.phases[:inHead]
        appendToHead(element)
      else
        @tree.openElements[-1].appendChild(element)
      end
    end

    def startTagOther(name, attributes)
      anythingElse
      @parser.phase.processStartTag(name, attributes)
    end

    def endTagHead(name)
      if @tree.openElements[-1].name == 'head'
        @tree.openElements.pop
      else
        @parser.parseError(_("Unexpected end tag (head). Ignored."))
      end
      @parser.phase = @parser.phases[:afterHead]
    end

    def endTagImplyAfterHead(name)
      anythingElse
      @parser.phase.processEndTag(name)
    end

    def endTagTitleStyleScript(name)
      if @tree.openElements[-1].name == name
        @tree.openElements.pop
      else
        @parser.parseError(_("Unexpected end tag (#{name}). Ignored."))
      end
    end

    def endTagOther(name)
      @parser.parseError(_("Unexpected end tag (#{name}). Ignored."))
    end

    def anythingElse
      if @tree.openElements[-1].name == 'head'
        endTagHead('head')
      else
        @parser.phase = @parser.phases[:afterHead]
      end
    end

    protected

    def appendToHead(element)
      if @tree.headPointer.nil?
        assert @parser.innerHTML
        @tree.openElements[-1].appendChild(element)
      else
        @tree.headPointer.appendChild(element)
      end
    end

  end
end
