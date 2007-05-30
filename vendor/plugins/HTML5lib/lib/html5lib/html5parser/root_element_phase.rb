require 'html5lib/html5parser/phase'

module HTML5lib
  class RootElementPhase < Phase

    def processEOF
      insertHtmlElement
      @parser.phase.processEOF
    end

    def processComment(data)
      @tree.insertComment(data, @tree.document)
    end

    def processSpaceCharacters(data)
      @tree.insertText(data, @tree.document)
    end

    def processCharacters(data)
      insertHtmlElement
      @parser.phase.processCharacters(data)
    end

    def processStartTag(name, attributes)
      @parser.firstStartTag = true if name == 'html'
      insertHtmlElement
      @parser.phase.processStartTag(name, attributes)
    end

    def processEndTag(name)
      insertHtmlElement
      @parser.phase.processEndTag(name)
    end

    def insertHtmlElement
      element = @tree.createElement('html', {})
      @tree.openElements.push(element)
      @tree.document.appendChild(element)
      @parser.phase = @parser.phases[:beforeHead]
    end

  end
end