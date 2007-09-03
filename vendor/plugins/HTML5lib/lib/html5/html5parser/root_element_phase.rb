require 'html5/html5parser/phase'

module HTML5
  class RootElementPhase < Phase

    def process_eof
      insert_html_element
      @parser.phase.process_eof
    end

    def processComment(data)
      @tree.insert_comment(data, @tree.document)
    end

    def processSpaceCharacters(data)
    end

    def processCharacters(data)
      insert_html_element
      @parser.phase.processCharacters(data)
    end

    def processStartTag(name, attributes)
      @parser.first_start_tag = true if name == 'html'
      insert_html_element
      @parser.phase.processStartTag(name, attributes)
    end

    def processEndTag(name)
      insert_html_element
      @parser.phase.processEndTag(name)
    end

    def insert_html_element
      element = @tree.createElement('html', {})
      @tree.open_elements.push(element)
      @tree.document.appendChild(element)
      @parser.phase = @parser.phases[:beforeHead]
    end

  end
end