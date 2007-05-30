# Warning: this module is experimental and subject to change and even removal
# at any time. 
# 
# For background/rationale, see:
#  * http://www.intertwingly.net/blog/2007/01/08/Xhtml5lib
#  * http://tinyurl.com/ylfj8k (and follow-ups)
# 
# References:
#  * http://googlereader.blogspot.com/2005/12/xml-errors-in-feeds.html
#  * http://wiki.whatwg.org/wiki/HtmlVsXhtml
# 
# @@TODO:
# * Selectively lowercase only XHTML, but not foreign markup
require 'html5lib/html5parser'
require 'html5lib/constants'

module HTML5lib

  # liberal XML parser
  class XMLParser < HTMLParser

    def initialize(options = {})
      super options
      @phases[:initial] = XmlRootPhase.new(self, @tree)
    end

    def normalizeToken(token)
      if token[:type] == :StartTag or token[:type] == :EmptyTag
        # We need to remove the duplicate attributes and convert attributes
        # to a dict so that [["x", "y"], ["x", "z"]] becomes {"x": "y"}

        token[:data] = Hash[*token[:data].reverse.flatten]

        # For EmptyTags, process both a Start and an End tag
        if token[:type] == :EmptyTag
          @phase.processStartTag(token[:name], token[:data])
          token[:data] = {}
          token[:type] = :EndTag
        end

      elsif token[:type] == :EndTag
        if token[:data]
           parseError(_("End tag contains unexpected attributes."))
        end

      elsif token[:type] == :Comment
        # Rescue CDATA from the comments
        if token[:data][0..6] == "[CDATA[" and token[:data][-2..-1] == "]]"
          token[:type] = :Characters
          token[:data] = token[:data][7 ... -2]
        end
      end

      return token
    end
  end

  # liberal XMTHML parser
  class XHTMLParser < XMLParser

    def initialize(options = {})
      super options
      @phases[:initial] = InitialPhase.new(self, @tree)
      @phases[:rootElement] = XhmlRootPhase.new(self, @tree)
    end

    def normalizeToken(token)
      super(token)

      # ensure that non-void XHTML elements have content so that separate
      # open and close tags are emitted
      if token[:type]  == :EndTag and \
        not VOID_ELEMENTS.include? token[:name] and \
        token[:name] == @tree.openElements[-1].name and \
        not @tree.openElements[-1].hasContent
        @tree.insertText('') unless
          @tree.openElements.any? {|e|
            e.attributes.keys.include? 'xmlns' and
            e.attributes['xmlns'] != 'http://www.w3.org/1999/xhtml'
          }
      end

      return token
    end
  end

  class XhmlRootPhase < RootElementPhase
    def insertHtmlElement
      element = @tree.createElement("html", {'xmlns' => 'http://www.w3.org/1999/xhtml'})
      @tree.openElements.push(element)
      @tree.document.appendChild(element)
      @parser.phase = @parser.phases[:beforeHead]
    end
  end

  class XmlRootPhase < Phase
    # Prime the Xml parser
    @start_tag_handlers = Hash.new(:startTagOther)
    @end_tag_handlers = Hash.new(:endTagOther)
    def startTagOther(name, attributes)
      @tree.openElements.push(@tree.document)
      element = @tree.createElement(name, attributes)
      @tree.openElements[-1].appendChild(element)
      @tree.openElements.push(element)
      @parser.phase = XmlElementPhase.new(@parser,@tree)
    end
    def endTagOther(name)
      super
      @tree.openElements.pop
    end
  end

  class XmlElementPhase < Phase
    # Generic handling for all XML elements

    @start_tag_handlers = Hash.new(:startTagOther)
    @end_tag_handlers = Hash.new(:endTagOther)

    def startTagOther(name, attributes)
      element = @tree.createElement(name, attributes)
      @tree.openElements[-1].appendChild(element)
      @tree.openElements.push(element)
    end

    def endTagOther(name)
      for node in @tree.openElements.reverse
        if node.name == name
          {} while @tree.openElements.pop != node
          break
        else
          @parser.parseError
        end
      end
    end

    def processCharacters(data)
      @tree.insertText(data)
    end
  end

end
