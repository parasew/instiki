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
require 'html5/html5parser'
require 'html5/constants'

module HTML5

  # liberal XML parser
  class XMLParser < HTMLParser

    def initialize(options = {})
      super options
      @phases[:initial] = XmlRootPhase.new(self, @tree)
    end

    def normalize_token(token)
      case token[:type]
      when :StartTag, :EmptyTag
        # We need to remove the duplicate attributes and convert attributes
        # to a Hash so that [["x", "y"], ["x", "z"]] becomes {"x": "y"}

        token[:data] = Hash[*token[:data].reverse.flatten]

        # For EmptyTags, process both a Start and an End tag
        if token[:type] == :EmptyTag
          save = @tokenizer.content_model_flag
          @phase.processStartTag(token[:name], token[:data])
          @tokenizer.content_model_flag = save
          token[:data] = {}
          token[:type] = :EndTag
        end

      when :Characters
        # un-escape RCDATA_ELEMENTS (e.g. style, script)
        if @tokenizer.content_model_flag == :CDATA
          token[:data] = token[:data].
            gsub('&lt;','<').gsub('&gt;','>').gsub('&amp;','&')
        end

      when :EndTag
        if token[:data]
           parse_error(_("End tag contains unexpected attributes."))
        end

      when :Comment
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

    def normalize_token(token)
      super(token)

      # ensure that non-void XHTML elements have content so that separate
      # open and close tags are emitted
      if token[:type]  == :EndTag
        if VOID_ELEMENTS.include? token[:name]
          if @tree.open_elements[-1].name != token["name"]:
            token[:type] = :EmptyTag
            token["data"] ||= {}
          end
        else
          if token[:name] == @tree.open_elements[-1].name and \
            not @tree.open_elements[-1].hasContent
            @tree.insertText('') unless
              @tree.open_elements.any? {|e|
                e.attributes.keys.include? 'xmlns' and
                e.attributes['xmlns'] != 'http://www.w3.org/1999/xhtml'
              }
           end
        end
      end

      return token
    end
  end

  class XhmlRootPhase < RootElementPhase
    def insert_html_element
      element = @tree.createElement("html", {'xmlns' => 'http://www.w3.org/1999/xhtml'})
      @tree.open_elements.push(element)
      @tree.document.appendChild(element)
      @parser.phase = @parser.phases[:beforeHead]
    end
  end

  class XmlRootPhase < Phase
    # Prime the Xml parser
    @start_tag_handlers = Hash.new(:startTagOther)
    @end_tag_handlers = Hash.new(:endTagOther)
    def startTagOther(name, attributes)
      @tree.open_elements.push(@tree.document)
      element = @tree.createElement(name, attributes)
      @tree.open_elements[-1].appendChild(element)
      @tree.open_elements.push(element)
      @parser.phase = XmlElementPhase.new(@parser,@tree)
    end
    def endTagOther(name)
      super
      @tree.open_elements.pop
    end
  end

  class XmlElementPhase < Phase
    # Generic handling for all XML elements

    @start_tag_handlers = Hash.new(:startTagOther)
    @end_tag_handlers = Hash.new(:endTagOther)

    def startTagOther(name, attributes)
      element = @tree.createElement(name, attributes)
      @tree.open_elements[-1].appendChild(element)
      @tree.open_elements.push(element)
    end

    def endTagOther(name)
      for node in @tree.open_elements.reverse
        if node.name == name
          {} while @tree.open_elements.pop != node
          break
        else
          parse_error
        end
      end
    end

    def processCharacters(data)
      @tree.insertText(data)
    end
  end

end
