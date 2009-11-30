require 'html5/html5parser/phase'

module HTML5
  class InHeadPhase < Phase

    handle_start 'html', 'head', 'title', 'style', 'script', 'noscript'
    handle_start %w( base link meta )

    handle_end 'head'
    handle_end %w( html body br p ) => 'ImplyAfterHead'
    handle_end %w( title style script noscript )

    def process_eof
      if ['title', 'style', 'script'].include?(name = @tree.open_elements.last.name)
        parse_error("expected-named-closing-tag-but-got-eof", {"name" => @tree.open_elements.last.name})
        @tree.open_elements.pop
      end
      anything_else
      @parser.phase.process_eof
    end

    def processCharacters(data)
      if %w[title style script noscript].include?(@tree.open_elements.last.name)
        @tree.insertText(data)
      else
        anything_else
        @parser.phase.processCharacters(data)
      end
    end

    def startTagHead(name, attributes)
      parse_error("two-heads-are-not-better-than-one")
    end

    def startTagTitle(name, attributes)
      element = @tree.createElement(name, attributes)
      appendToHead(element)
      @tree.open_elements.push(element)
      @parser.tokenizer.content_model_flag = :RCDATA
    end

    def startTagStyle(name, attributes)
      element = @tree.createElement(name, attributes)
      if @tree.head_pointer != nil and @parser.phase == @parser.phases[:inHead]
        appendToHead(element)
      else
        @tree.open_elements.last.appendChild(element)
      end
      @tree.open_elements.push(element)
      @parser.tokenizer.content_model_flag = :CDATA
    end

    def startTagNoscript(name, attributes)
      # XXX Need to decide whether to implement the scripting disabled case.
      element = @tree.createElement(name, attributes)
      if @tree.head_pointer !=nil and @parser.phase == @parser.phases[:inHead]
        appendToHead(element)
      else
        @tree.open_elements.last.appendChild(element)
      end
      @tree.open_elements.push(element)
      @parser.tokenizer.content_model_flag = :CDATA
    end

    def startTagScript(name, attributes)
      #XXX Inner HTML case may be wrong
      element = @tree.createElement(name, attributes)
      element._flags.push("parser-inserted")
      if @tree.head_pointer != nil and @parser.phase == @parser.phases[:inHead]
        appendToHead(element)
      else
        @tree.open_elements.last.appendChild(element)
      end
      @tree.open_elements.push(element)
      @parser.tokenizer.content_model_flag = :CDATA
    end

    def startTagBaseLinkMeta(name, attributes)
      element = @tree.createElement(name, attributes)
      if @tree.head_pointer != nil and @parser.phase == @parser.phases[:inHead]
        appendToHead(element)
      else
        @tree.open_elements.last.appendChild(element)
      end
    end

    def startTagOther(name, attributes)
      anything_else
      @parser.phase.processStartTag(name, attributes)
    end

    def endTagHead(name)
      if @tree.open_elements.last.name == 'head'
        @tree.open_elements.pop
      else
        parse_error("unexpected-end-tag", {"name" => "head"})
      end
      @parser.phase = @parser.phases[:afterHead]
    end

    def endTagImplyAfterHead(name)
      anything_else
      @parser.phase.processEndTag(name)
    end

    def endTagTitleStyleScriptNoscript(name)
      if @tree.open_elements.last.name == name
        @tree.open_elements.pop
      else
        parse_error("unexpected-end-tag", {"name" => name})
      end
    end

    def endTagOther(name)
      parse_error("unexpected-end-tag", {"name" => name})
    end

    def anything_else
      if @tree.open_elements.last.name == 'head'
        endTagHead('head')
      else
        @parser.phase = @parser.phases[:afterHead]
      end
    end

    protected

    def appendToHead(element)
      if @tree.head_pointer.nil?
        assert @parser.inner_html
        @tree.open_elements.last.appendChild(element)
      else
        @tree.head_pointer.appendChild(element)
      end
    end

  end
end
