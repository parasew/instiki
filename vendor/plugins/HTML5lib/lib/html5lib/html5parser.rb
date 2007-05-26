require 'html5lib/constants'
require 'html5lib/tokenizer'
require 'html5lib/treebuilders/rexml'

module HTML5lib

# HTML parser. Generates a tree structure from a stream of (possibly
# malformed) HTML
class HTMLParser

    attr_accessor :phase, :firstStartTag, :innerHTML, :lastPhase, :insertFromTable

    attr_reader :phases, :tokenizer, :tree, :errors

    # convenience methods
    def self.parse(stream, options = {})
        encoding = options.delete(:encoding)
        new(options).parse(stream,encoding)
    end

    def self.parseFragment(stream, options = {})
        container = options.delete(:container) || 'div'
        encoding = options.delete(:encoding)
        new(options).parseFragment(stream,container,encoding)
    end

    @@phases = [
        :initial,
        :rootElement,
        :beforeHead,
        :inHead,
        :afterHead,
        :inBody,
        :inTable,
        :inCaption,
        :inColumnGroup,
        :inTableBody,
        :inRow,
        :inCell,
        :inSelect,
        :afterBody,
        :inFrameset,
        :afterFrameset,
        :trailingEnd
    ]

    # :strict - raise an exception when a parse error is encountered
    # :tree - a treebuilder class controlling the type of tree that will be
    # returned. Built in treebuilders can be accessed through
    # html5lib.treebuilders.getTreeBuilder(treeType)
    def initialize(options = {})
        @strict = false
        @errors = []
       
        @tokenizer =  HTMLTokenizer
        @tree = TreeBuilders::REXMLTree::TreeBuilder
 
        options.each { |name, value| instance_variable_set("@#{name}", value) }

        @tree = @tree.new

        @phases = @@phases.inject({}) do |phases, symbol|
            class_name = symbol.to_s.sub(/(.)/) { $1.upcase } + 'Phase'
            phases[symbol] = HTML5lib.const_get(class_name).new(self, @tree)
            phases 
        end
    end

    def _parse(stream, innerHTML, encoding, container = 'div')
        @tree.reset
        @firstStartTag = false
        @errors = []

        @tokenizer = @tokenizer.class unless Class === @tokenizer
        @tokenizer = @tokenizer.new(stream, :encoding => encoding, :parseMeta => innerHTML)

        if innerHTML
            case @innerHTML = container.downcase
                when 'title', 'textarea'
                    @tokenizer.contentModelFlag = :RCDATA
                when 'style', 'script', 'xmp', 'iframe', 'noembed', 'noframes', 'noscript'
                    @tokenizer.contentModelFlag = :CDATA
                when 'plaintext'
                    @tokenizer.contentModelFlag = :PLAINTEXT
                else
                # contentModelFlag already is PCDATA
                #@tokenizer.contentModelFlag = :PCDATA
            end
            
            @phase = @phases[:rootElement]
            @phase.insertHtmlElement
            resetInsertionMode
        else
            @innerHTML = false
            @phase = @phases[:initial]
        end

        # We only seem to have InBodyPhase testcases where the following is
        # relevant ... need others too
        @lastPhase = nil

        # XXX This is temporary for the moment so there isn't any other
        # changes needed for the parser to work with the iterable tokenizer
        @tokenizer.each do |token|
            token = normalizeToken(token)

            method = 'process%s' % token[:type]

            case token[:type]
                when :Characters, :SpaceCharacters, :Comment
                    @phase.send method, token[:data]
                when :StartTag, :Doctype
                    @phase.send method, token[:name], token[:data]
                when :EndTag
                    @phase.send method, token[:name]
                else
                    parseError(token[:data])
            end
        end

        # When the loop finishes it's EOF
        @phase.processEOF
     end

     # Parse a HTML document into a well-formed tree
     #
     # stream - a filelike object or string containing the HTML to be parsed
     #
     # The optional encoding parameter must be a string that indicates
     # the encoding.  If specified, that encoding will be used,
     # regardless of any BOM or later declaration (such as in a meta
     # element)
    def parse(stream, encoding = nil)
        _parse(stream, false, encoding)
        return @tree.getDocument
    end
    
    # Parse a HTML fragment into a well-formed tree fragment
        
    # container - name of the element we're setting the innerHTML property
    # if set to nil, default to 'div'
    #
    # stream - a filelike object or string containing the HTML to be parsed
    #
    # The optional encoding parameter must be a string that indicates
    # the encoding.  If specified, that encoding will be used,
    # regardless of any BOM or later declaration (such as in a meta
    # element)
    def parseFragment(stream, container = 'div', encoding = nil)
        _parse(stream, true, encoding, container)
        return @tree.getFragment
    end

    def parseError(data = 'XXX ERROR MESSAGE NEEDED')
        # XXX The idea is to make data mandatory.
        @errors.push([@tokenizer.stream.position, data])
        raise ParseError if @strict
    end

    # This error is not an error
    def atheistParseError
    end

    # HTML5 specific normalizations to the token stream
    def normalizeToken(token)

        if token[:type] == :EmptyTag
            # When a solidus (/) is encountered within a tag name what happens
            # depends on whether the current tag name matches that of a void
            # element.  If it matches a void element atheists did the wrong
            # thing and if it doesn't it's wrong for everyone.

            if VOID_ELEMENTS.include?(token[:name])
                atheistParseError
            else
                parseError(_('Solidus (/) incorrectly placed in tag.'))
            end

            token[:type] = :StartTag
        end

        if token[:type] == :StartTag
            token[:name] = token[:name].tr(ASCII_UPPERCASE,ASCII_LOWERCASE)

            # We need to remove the duplicate attributes and convert attributes
            # to a dict so that [["x", "y"], ["x", "z"]] becomes {"x": "y"}

            if token[:data].length
                token[:data] = Hash[*token[:data].reverse.map {|attr,value|
                  [attr.tr(ASCII_UPPERCASE,ASCII_LOWERCASE),value]
                }.flatten]
            else
                token[:data] = {}
            end

        elsif token[:type] == :EndTag
            parseError(_('End tag contains unexpected attributes.')) if token[:data]
            token[:name] = token[:name].downcase
        end

        return token
    end

    @@new_modes = {
        'select' => :inSelect,
        'td' => :inCell,
        'th' => :inCell,
        'tr' => :inRow,
        'tbody' => :inTableBody,
        'thead' => :inTableBody,
        'tfoot' => :inTableBody,
        'caption' => :inCaption,
        'colgroup' => :inColumnGroup,
        'table' => :inTable,
        'head' => :inBody,
        'body' => :inBody,
        'frameset' => :inFrameset
    }

    def resetInsertionMode
        # The name of this method is mostly historical. (It's also used in the
        # specification.)
        last = false

        @tree.openElements.reverse.each do |node|
            nodeName = node.name

            if node == @tree.openElements[0]
                last = true
                unless ['td', 'th'].include?(nodeName)
                    # XXX
                    # assert @innerHTML
                    nodeName = @innerHTML
                end
            end

            # Check for conditions that should only happen in the innerHTML
            # case
            if ['select', 'colgroup', 'head', 'frameset'].include?(nodeName)
                # XXX
                # assert @innerHTML
            end

            if @@new_modes.has_key?(nodeName)
                @phase = @phases[@@new_modes[nodeName]]
            elsif nodeName == 'html'
                @phase = @phases[@tree.headPointer.nil?? :beforeHead : :afterHead]
            elsif last
                @phase = @phases[:inBody]
            else
                next
            end

            break
        end
    end

    def _(string); string; end
end

# Base class for helper object that implements each phase of processing
class Phase
    # Order should be (they can be omitted)
    # * EOF
    # * Comment
    # * Doctype
    # * SpaceCharacters
    # * Characters
    # * StartTag
    #   - startTag* methods
    # * EndTag
    #   - endTag* methods

   def self.tag_handler_map(default,array)
        array.inject(Hash.new(default)) do |map, (names, value)|
            names = [names] unless Array === names
            names.each { |name| map[name] = value }
            map
        end
    end

    def self.start_tag_handlers
        @start_tag_handlers
    end

    def self.handle_start(tags)
        @start_tag_handlers = tag_handler_map(:startTagOther, tags)
    end

    def self.end_tag_handlers
        @end_tag_handlers
    end

    def self.handle_end(tags)
        @end_tag_handlers = tag_handler_map(:endTagOther, tags)
    end

    def initialize(parser, tree)
        @parser = parser
        @tree = tree
    end

    def processEOF
        @tree.generateImpliedEndTags

        if @tree.openElements.length > 2
            @parser.parseError(_('Unexpected end of file. Missing closing tags.'))
        elsif @tree.openElements.length == 2 and @tree.openElements[1].name != 'body'
            # This happens for framesets or something?
            @parser.parseError(_("Unexpected end of file. Expected end tag (#{@tree.openElements[1].name}) first."))
        elsif @parser.innerHTML and @tree.openElements.length > 1 
            # XXX This is not what the specification says. Not sure what to do here.
            @parser.parseError(_('XXX innerHTML EOF'))
        end
        # Betting ends.
    end

    def processComment(data)
        # For most phases the following is correct. Where it's not it will be
        # overridden.
        @tree.insertComment(data, @tree.openElements[-1])
    end

    def processDoctype(name, error)
        @parser.parseError(_('Unexpected DOCTYPE. Ignored.'))
    end

    def processSpaceCharacters(data)
        @tree.insertText(data)
    end

    def processStartTag(name, attributes)
        send self.class.start_tag_handlers[name], name, attributes
    end

    def startTagHtml(name, attributes)
        if @parser.firstStartTag == false and name == 'html'
           @parser.parseError(_('html needs to be the first start tag.'))
        end
        # XXX Need a check here to see if the first start tag token emitted is
        # this token... If it's not, invoke @parser.parseError.
        attributes.each do |attr, value|
            unless @tree.openElements[0].attributes.has_key?(attr)
                @tree.openElements[0].attributes[attr] = value
            end
        end
        @parser.firstStartTag = false
    end

    def processEndTag(name)
        send self.class.end_tag_handlers[name], name
    end

    def _(string)
        string
    end

    def assert(value)
        throw AssertionError.new unless value
    end

    def in_scope?(*args)
        @tree.elementInScope(*args)
    end

    def remove_open_elements_until(name = nil)
        finished = false
        until finished
            element = @tree.openElements.pop
            finished = name.nil?? yield(element) : element.name == name
        end
        return element
    end

end


class InitialPhase < Phase
    # This phase deals with error handling as well which is currently not
    # covered in the specification. The error handling is typically known as
    # "quirks mode". It is expected that a future version of HTML5 will defin
    # this.
    def processEOF
        @parser.parseError(_('Unexpected End of file. Expected DOCTYPE.'))
        @parser.phase = @parser.phases[:rootElement]
        @parser.phase.processEOF
    end

    def processComment(data)
        @tree.insertComment(data, @tree.document)
    end

    def processDoctype(name, error)
        @parser.parseError(_('Erroneous DOCTYPE.')) if error
        @tree.insertDoctype(name)
        @parser.phase = @parser.phases[:rootElement]
    end

    def processSpaceCharacters(data)
        @tree.insertText(data, @tree.document)
    end

    def processCharacters(data)
        @parser.parseError(_('Unexpected non-space characters. Expected DOCTYPE.'))
        @parser.phase = @parser.phases[:rootElement]
        @parser.phase.processCharacters(data)
    end

    def processStartTag(name, attributes)
        @parser.parseError(_("Unexpected start tag (#{name}). Expected DOCTYPE."))
        @parser.phase = @parser.phases[:rootElement]
        @parser.phase.processStartTag(name, attributes)
    end

    def processEndTag(name)
        @parser.parseError(_("Unexpected end tag (#{name}). Expected DOCTYPE."))
        @parser.phase = @parser.phases[:rootElement]
        @parser.phase.processEndTag(name)
    end
end


class RootElementPhase < Phase
    # helper methods
    def insertHtmlElement
        element = @tree.createElement('html', {})
        @tree.openElements.push(element)
        @tree.document.appendChild(element)
        @parser.phase = @parser.phases[:beforeHead]
    end

    # other
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
end


class BeforeHeadPhase < Phase

    handle_start [
        ['html', :startTagHtml],
        ['head', :startTagHead]
    ]

    handle_end [
        ['html', :endTagHtml]
    ]

    def processEOF
        startTagHead('head', {})
        @parser.phase.processEOF
    end

    def processCharacters(data)
        startTagHead('head', {})
        @parser.phase.processCharacters(data)
    end

    def startTagHead(name, attributes)
        @tree.insertElement(name, attributes)
        @tree.headPointer = @tree.openElements[-1]
        @parser.phase = @parser.phases[:inHead]
    end

    def startTagOther(name, attributes)
        startTagHead('head', {})
        @parser.phase.processStartTag(name, attributes)
    end

    def endTagHtml(name)
        startTagHead('head', {})
        @parser.phase.processEndTag(name)
    end

    def endTagOther(name)
        @parser.parseError(_("Unexpected end tag (#{name}) after the (implied) root element."))
    end
end

class InHeadPhase < Phase

    handle_start [
        ['html', :startTagHtml],
        ['title', :startTagTitle],
        ['style', :startTagStyle],
        ['script', :startTagScript],
        [['base', 'link', 'meta'], :startTagBaseLinkMeta],
        ['head', :startTagHead]
    ]

    handle_end [
        ['head', :endTagHead],
        ['html', :endTagHtml],
        [['title', 'style', 'script'], :endTagTitleStyleScript]
    ]

    # helper
    def appendToHead(element)
        if @tree.headPointer.nil?
            assert @parser.innerHTML
            @tree.openElements[-1].appendChild(element)
        else
            @tree.headPointer.appendChild(element)
        end
    end

    # the real thing
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
        appendToHead(element)
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

    def endTagHtml(name)
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
end

class AfterHeadPhase < Phase
    
    handle_start [
        ['html', :startTagHtml],
        ['body', :startTagBody],
        ['frameset', :startTagFrameset],
        [['base', 'link', 'meta', 'script', 'style', 'title'], :startTagFromHead]
    ]

    def processEOF
        anythingElse
        @parser.phase.processEOF
    end

    def processCharacters(data)
        anythingElse
        @parser.phase.processCharacters(data)
    end

    def startTagBody(name, attributes)
        @tree.insertElement(name, attributes)
        @parser.phase = @parser.phases[:inBody]
    end

    def startTagFrameset(name, attributes)
        @tree.insertElement(name, attributes)
        @parser.phase = @parser.phases[:inFrameset]
    end

    def startTagFromHead(name, attributes)
        @parser.parseError(_("Unexpected start tag (#{name}) that can be in head. Moved."))
        @parser.phase = @parser.phases[:inHead]
        @parser.phase.processStartTag(name, attributes)
    end

    def startTagOther(name, attributes)
        anythingElse
        @parser.phase.processStartTag(name, attributes)
    end

    def processEndTag(name)
        anythingElse
        @parser.phase.processEndTag(name)
    end

    def anythingElse
        @tree.insertElement('body', {})
        @parser.phase = @parser.phases[:inBody]
    end
end


class InBodyPhase < Phase
    # http://www.whatwg.org/specs/web-apps/current-work/#in-body
    # the crazy mode

    handle_start [
        ['html', :startTagHtml],
        [['script', 'style'], :startTagScriptStyle],
        [['base', 'link', 'meta', 'title'], :startTagFromHead],
        ['body', :startTagBody],
        [['address', 'blockquote', 'center', 'dir', 'div', 'dl',
          'fieldset', 'listing', 'menu', 'ol', 'p', 'pre', 'ul'],
          :startTagCloseP],
        ['form', :startTagForm],
        [['li', 'dd', 'dt'], :startTagListItem],
        ['plaintext',:startTagPlaintext],
        [HEADING_ELEMENTS, :startTagHeading],
        ['a', :startTagA],
        [['b', 'big', 'em', 'font', 'i', 'nobr', 's', 'small', 'strike',
          'strong', 'tt', 'u'],:startTagFormatting],
        ['button', :startTagButton],
        [['marquee', 'object'], :startTagMarqueeObject],
        ['xmp', :startTagXmp],
        ['table', :startTagTable],
        [['area', 'basefont', 'bgsound', 'br', 'embed', 'img', 'param',
          'spacer', 'wbr'], :startTagVoidFormatting],
        ['hr', :startTagHr],
        ['image', :startTagImage],
        ['input', :startTagInput],
        ['isindex', :startTagIsIndex],
        ['textarea', :startTagTextarea],
        [['iframe', 'noembed', 'noframes', 'noscript'], :startTagCdata],
        ['select', :startTagSelect],
        [['caption', 'col', 'colgroup', 'frame', 'frameset', 'head',
          'option', 'optgroup', 'tbody', 'td', 'tfoot', 'th', 'thead',
          'tr'], :startTagMisplaced],
        [['event-source', 'section', 'nav', 'article', 'aside', 'header',
          'footer', 'datagrid', 'command'], :startTagNew]
    ]

    handle_end [
        ['p',:endTagP],
        ['body',:endTagBody],
        ['html',:endTagHtml],
        [['address', 'blockquote', 'center', 'div', 'dl', 'fieldset',
          'listing', 'menu', 'ol', 'pre', 'ul'], :endTagBlock],
        ['form', :endTagForm],
        [['dd', 'dt', 'li'], :endTagListItem],
        [HEADING_ELEMENTS, :endTagHeading],
        [['a', 'b', 'big', 'em', 'font', 'i', 'nobr', 's', 'small',
          'strike', 'strong', 'tt', 'u'], :endTagFormatting],
        [['marquee', 'object', 'button'], :endTagButtonMarqueeObject],
        [['head', 'frameset', 'select', 'optgroup', 'option', 'table',
          'caption', 'colgroup', 'col', 'thead', 'tfoot', 'tbody', 'tr',
          'td', 'th'], :endTagMisplaced],
        [['area', 'basefont', 'bgsound', 'br', 'embed', 'hr', 'image',
          'img', 'input', 'isindex', 'param', 'spacer', 'wbr', 'frame'],
          :endTagNone],
        [['noframes', 'noscript', 'noembed', 'textarea', 'xmp', 'iframe'],
          :endTagCdataTextAreaXmp],
        [['event-source', 'section', 'nav', 'article', 'aside', 'header',
          'footer', 'datagrid', 'command'], :endTagNew]
    ]

    def initialize(parser, tree)
        super(parser, tree)

        # for special handling of whitespace in <pre>
        @processSpaceCharactersPre = false
    end

    # helper
    def addFormattingElement(name, attributes)
        @tree.insertElement(name, attributes)
        @tree.activeFormattingElements.push(@tree.openElements[-1])
    end

    # the real deal
    def processSpaceCharactersPre(data)
        #Sometimes (start of <pre> blocks) we want to drop leading newlines
        @processSpaceCharactersPre = false
        if (data.length > 0 and data[0] == ?\n and 
            @tree.openElements[-1].name == 'pre' and
            not @tree.openElements[-1].hasContent)
            data = data[1..-1]
        end
        @tree.insertText(data) if data.length > 0
    end

    def processSpaceCharacters(data)
        if @processSpaceCharactersPre
            processSpaceCharactersPre(data)
        else
            super(data)
        end
    end

    def processCharacters(data)
        # XXX The specification says to do this for every character at the
        # moment, but apparently that doesn't match the real world so we don't
        # do it for space characters.
        @tree.reconstructActiveFormattingElements
        @tree.insertText(data)
    end

    def startTagScriptStyle(name, attributes)
        @parser.phases[:inHead].processStartTag(name, attributes)
    end

    def startTagFromHead(name, attributes)
        @parser.parseError(_("Unexpected start tag (#{name}) that belongs in the head. Moved."))
        @parser.phases[:inHead].processStartTag(name, attributes)
    end

    def startTagBody(name, attributes)
        @parser.parseError(_('Unexpected start tag (body).'))

        if (@tree.openElements.length == 1 or
            @tree.openElements[1].name != 'body')
            assert @parser.innerHTML
        else
            attributes.each do |attr, value|
                unless @tree.openElements[1].attributes.has_key?(attr)
                    @tree.openElements[1].attributes[attr] = value
                end
            end
        end
    end

    def startTagCloseP(name, attributes)
        endTagP('p') if in_scope?('p')
        @tree.insertElement(name, attributes)
        @processSpaceCharactersPre = true if name == 'pre'
    end

    def startTagForm(name, attributes)
        if @tree.formPointer
            @parser.parseError('Unexpected start tag (form). Ignored.')
        else
            endTagP('p') if in_scope?('p')
            @tree.insertElement(name, attributes)
            @tree.formPointer = @tree.openElements[-1]
        end
    end

    def startTagListItem(name, attributes)
        endTagP('p') if in_scope?('p')
        stopNames = {'li' => ['li'], 'dd' => ['dd', 'dt'], 'dt' => ['dd', 'dt']}
        stopName = stopNames[name]

        @tree.openElements.reverse.each_with_index do |node,i|
            if stopName.include?(node.name)
                (i+1).times { @tree.openElements.pop }
                break
            end

            # Phrasing elements are all non special, non scoping, non
            # formatting elements
            break if ((SPECIAL_ELEMENTS + SCOPING_ELEMENTS).include?(node.name) and
              not ['address', 'div'].include?(node.name))
        end

        # Always insert an <li> element.
        @tree.insertElement(name, attributes)
    end

    def startTagPlaintext(name, attributes)
        endTagP('p') if in_scope?('p')
        @tree.insertElement(name, attributes)
        @parser.tokenizer.contentModelFlag = :PLAINTEXT
    end

    def startTagHeading(name, attributes)
        endTagP('p') if in_scope?('p')
        HEADING_ELEMENTS.each do |element|
            if in_scope?(element)
                @parser.parseError(_("Unexpected start tag (#{name})."))
                
                remove_open_elements_until { |element| HEADING_ELEMENTS.include?(element.name) }

                break
             end
        end
        @tree.insertElement(name, attributes)
    end

    def startTagA(name, attributes)
        if afeAElement = @tree.elementInActiveFormattingElements('a')
            @parser.parseError(_('Unexpected start tag (a) implies end tag (a).'))
            endTagFormatting('a')
            @tree.openElements.delete(afeAElement) if @tree.openElements.include?(afeAElement)
            @tree.activeFormattingElements.delete(afeAElement) if @tree.activeFormattingElements.include?(afeAElement)
        end
        @tree.reconstructActiveFormattingElements
        addFormattingElement(name, attributes)
    end

    def startTagFormatting(name, attributes)
        @tree.reconstructActiveFormattingElements
        addFormattingElement(name, attributes)
    end

    def startTagButton(name, attributes)
        if in_scope?('button')
            @parser.parseError(_('Unexpected start tag (button) implied end tag (button).'))
            processEndTag('button')
            @parser.phase.processStartTag(name, attributes)
        else
            @tree.reconstructActiveFormattingElements
            @tree.insertElement(name, attributes)
            @tree.activeFormattingElements.push(Marker)
        end
    end

    def startTagMarqueeObject(name, attributes)
        @tree.reconstructActiveFormattingElements
        @tree.insertElement(name, attributes)
        @tree.activeFormattingElements.push(Marker)
    end

    def startTagXmp(name, attributes)
        @tree.reconstructActiveFormattingElements
        @tree.insertElement(name, attributes)
        @parser.tokenizer.contentModelFlag = :CDATA
    end

    def startTagTable(name, attributes)
        processEndTag('p') if in_scope?('p')
        @tree.insertElement(name, attributes)
        @parser.phase = @parser.phases[:inTable]
    end

    def startTagVoidFormatting(name, attributes)
        @tree.reconstructActiveFormattingElements
        @tree.insertElement(name, attributes)
        @tree.openElements.pop
    end

    def startTagHr(name, attributes)
        endTagP('p') if in_scope?('p')
        @tree.insertElement(name, attributes)
        @tree.openElements.pop
    end

    def startTagImage(name, attributes)
        # No really...
        @parser.parseError(_('Unexpected start tag (image). Treated as img.'))
        processStartTag('img', attributes)
    end

    def startTagInput(name, attributes)
        @tree.reconstructActiveFormattingElements
        @tree.insertElement(name, attributes)
        if @tree.formPointer
            # XXX Not exactly sure what to do here
            # @tree.openElements[-1].form = @tree.formPointer
        end
        @tree.openElements.pop
    end

    def startTagIsIndex(name, attributes)
        @parser.parseError("Unexpected start tag isindex. Don't use it!")
        return if @tree.formPointer
        processStartTag('form', {})
        processStartTag('hr', {})
        processStartTag('p', {})
        processStartTag('label', {})
        # XXX Localization ...
        processCharacters('This is a searchable index. Insert your search keywords here:')
        attributes['name'] = 'isindex'
        attrs = attributes.to_a
        processStartTag('input', attributes)
        processEndTag('label')
        processEndTag('p')
        processStartTag('hr', {})
        processEndTag('form')
    end

    def startTagTextarea(name, attributes)
        # XXX Form element pointer checking here as well...
        @tree.insertElement(name, attributes)
        @parser.tokenizer.contentModelFlag = :RCDATA
    end

    # iframe, noembed noframes, noscript(if scripting enabled)
    def startTagCdata(name, attributes)
        @tree.insertElement(name, attributes)
        @parser.tokenizer.contentModelFlag = :CDATA
    end

    def startTagSelect(name, attributes)
        @tree.reconstructActiveFormattingElements
        @tree.insertElement(name, attributes)
        @parser.phase = @parser.phases[:inSelect]
    end

    def startTagMisplaced(name, attributes)
        # Elements that should be children of other elements that have a
        # different insertion mode; here they are ignored
        # "caption", "col", "colgroup", "frame", "frameset", "head",
        # "option", "optgroup", "tbody", "td", "tfoot", "th", "thead",
        # "tr", "noscript"
        @parser.parseError(_("Unexpected start tag (#{name}). Ignored."))
    end

    def startTagNew(name, attributes)
        # New HTML5 elements, "event-source", "section", "nav",
        # "article", "aside", "header", "footer", "datagrid", "command"
        sys.stderr.write("Warning: Undefined behaviour for start tag #{name}")
        startTagOther(name, attributes)
        #raise NotImplementedError
    end

    def startTagOther(name, attributes)
        @tree.reconstructActiveFormattingElements
        @tree.insertElement(name, attributes)
    end

    def endTagP(name)
        @tree.generateImpliedEndTags('p') if in_scope?('p')
        @parser.parseError('Unexpected end tag (p).') unless @tree.openElements[-1].name == 'p'
        @tree.openElements.pop while in_scope?('p')
    end

    def endTagBody(name)
        # XXX Need to take open <p> tags into account here. We shouldn't imply
        # </p> but we should not throw a parse error either. Specification is
        # likely to be updated.
        unless @tree.openElements[1].name == 'body'
            # innerHTML case
            @parser.parseError
            return
        end
        unless @tree.openElements[-1].name == 'body'
            @parser.parseError(_("Unexpected end tag (body). Missing end tag (#{@tree.openElements[-1].name})."))
        end
        @parser.phase = @parser.phases[:afterBody]
    end

    def endTagHtml(name)
        endTagBody(name)
        @parser.phase.processEndTag(name) unless @parser.innerHTML
    end

    def endTagBlock(name)
        #Put us back in the right whitespace handling mode
        @processSpaceCharactersPre = false if name == 'pre'

        @tree.generateImpliedEndTags if in_scope?(name)

        unless @tree.openElements[-1].name == name
            @parser.parseError(("End tag (#{name}) seen too early. Expected other end tag."))
        end

        if in_scope?(name)
            remove_open_elements_until(name)
        end
    end

    def endTagForm(name)
        endTagBlock(name)
        @tree.formPointer = nil
    end

    def endTagListItem(name)
        # AT Could merge this with the Block case
        if in_scope?(name)
            @tree.generateImpliedEndTags(name)

            unless @tree.openElements[-1].name == name
                @parser.parseError(("End tag (#{name}) seen too early. Expected other end tag."))
            end
        end

        remove_open_elements_until(name) if in_scope?(name)
    end    

    def endTagHeading(name)
        HEADING_ELEMENTS.each do |element|
            if in_scope?(element)
                @tree.generateImpliedEndTags
                break
            end
        end

        unless @tree.openElements[-1].name == name
            @parser.parseError(("Unexpected end tag (#{name}). Expected other end tag."))
        end

        HEADING_ELEMENTS.each do |element|
            if in_scope?(element)
                remove_open_elements_until { |element| HEADING_ELEMENTS.include?(element.name) }
                break
            end
        end
    end

    # The much-feared adoption agency algorithm
    def endTagFormatting(name)
        # http://www.whatwg.org/specs/web-apps/current-work/#adoptionAgency
        # XXX Better parseError messages appreciated.
        while true
            # Step 1 paragraph 1
            afeElement = @tree.elementInActiveFormattingElements(name)
            if not afeElement or (@tree.openElements.include?(afeElement) and not in_scope?(afeElement.name))
                @parser.parseError(_("End tag (#{name}) violates step 1, paragraph 1 of the adoption agency algorithm."))
                return
            # Step 1 paragraph 2
            elsif not @tree.openElements.include?(afeElement)
                @parser.parseError(_("End tag (#{name}) violates step 1, paragraph 2 of the adoption agency algorithm."))
                @tree.activeFormattingElements.delete(afeElement)
                return
            end

            # Step 1 paragraph 3
            if afeElement != @tree.openElements[-1]
                @parser.parseError(_("End tag (#{name}) violates step 1, paragraph 3 of the adoption agency algorithm."))
            end

            # Step 2
            # Start of the adoption agency algorithm proper
            afeIndex = @tree.openElements.index(afeElement)
            furthestBlock = nil
            @tree.openElements[afeIndex..-1].each do |element|
                if (SPECIAL_ELEMENTS + SCOPING_ELEMENTS).include?(element.name)
                    furthestBlock = element
                    break
                end
            end

            # Step 3
            if furthestBlock.nil?
                element = remove_open_elements_until { |element| element == afeElement }
                @tree.activeFormattingElements.delete(element)
                return
            end
            commonAncestor = @tree.openElements[afeIndex-1]

            # Step 5
            furthestBlock.parent.removeChild(furthestBlock) if furthestBlock.parent

            # Step 6
            # The bookmark is supposed to help us identify where to reinsert
            # nodes in step 12. We have to ensure that we reinsert nodes after
            # the node before the active formatting element. Note the bookmark
            # can move in step 7.4
            bookmark = @tree.activeFormattingElements.index(afeElement)

            # Step 7
            lastNode = node = furthestBlock
            while true
                # AT replace this with a function and recursion?
                # Node is element before node in open elements
                node = @tree.openElements[@tree.openElements.index(node)-1]
                until @tree.activeFormattingElements.include?(node)
                    tmpNode = node
                    node = @tree.openElements[@tree.openElements.index(node)-1]
                    @tree.openElements.delete(tmpNode)
                end
                # Step 7.3
                break if node == afeElement
                # Step 7.4
                if lastNode == furthestBlock
                    # XXX should this be index(node) or index(node)+1
                    # Anne: I think +1 is ok. Given x = [2,3,4,5]
                    # x.index(3) gives 1 and then x[1 +1] gives 4...
                    bookmark = @tree.activeFormattingElements.index(node) + 1
                end
                # Step 7.5
                cite = node.parent
                if node.hasContent
                    clone = node.cloneNode
                    # Replace node with clone
                    @tree.activeFormattingElements[@tree.activeFormattingElements.index(node)] = clone
                    @tree.openElements[@tree.openElements.index(node)] = clone
                    node = clone
                end
                # Step 7.6
                # Remove lastNode from its parents, if any
                lastNode.parent.removeChild(lastNode) if lastNode.parent
                node.appendChild(lastNode)
                # Step 7.7
                lastNode = node
                # End of inner loop
            end

            # Step 8
            lastNode.parent.removeChild(lastNode) if lastNode.parent
            commonAncestor.appendChild(lastNode)

            # Step 9
            clone = afeElement.cloneNode

            # Step 10
            furthestBlock.reparentChildren(clone)

            # Step 11
            furthestBlock.appendChild(clone)

            # Step 12
            @tree.activeFormattingElements.delete(afeElement)
            @tree.activeFormattingElements.insert([bookmark,@tree.activeFormattingElements.length].min, clone)

            # Step 13
            @tree.openElements.delete(afeElement)
            @tree.openElements.insert(@tree.openElements.index(furthestBlock) + 1, clone)
        end
    end

    def endTagButtonMarqueeObject(name)
        @tree.generateImpliedEndTags if in_scope?(name)

        unless @tree.openElements[-1].name == name
            @parser.parseError(_("Unexpected end tag (#{name}). Expected other end tag first."))
        end

        if in_scope?(name)
            remove_open_elements_until(name)
            
            @tree.clearActiveFormattingElements
        end
    end

    def endTagMisplaced(name)
        # This handles elements with end tags in other insertion modes.
        @parser.parseError(_("Unexpected end tag (#{name}). Ignored."))
    end

    def endTagNone(name)
        # This handles elements with no end tag.
        @parser.parseError(_("This tag (#{name}) has no end tag"))
    end

    def endTagCdataTextAreaXmp(name)
        if @tree.openElements[-1].name == name
            @tree.openElements.pop
        else
            @parser.parseError(_("Unexpected end tag (#{name}). Ignored."))
        end
    end

    def endTagNew(name)
        # New HTML5 elements, "event-source", "section", "nav",
        # "article", "aside", "header", "footer", "datagrid", "command"
        STDERR.puts "Warning: Undefined behaviour for end tag #{name}"
        endTagOther(name)
        #raise NotImplementedError
    end

    def endTagOther(name)
        # XXX This logic should be moved into the treebuilder
        @tree.openElements.reverse.each do |node|
            if node.name == name
                @tree.generateImpliedEndTags

                unless @tree.openElements[-1].name == name
                    @parser.parseError(_("Unexpected end tag (#{name})."))
                end

                remove_open_elements_until { |element| element == node }

                break
            else
                if (SPECIAL_ELEMENTS + SCOPING_ELEMENTS).include?(node.name)
                    @parser.parseError(_("Unexpected end tag (#{name}). Ignored."))
                    break
                end
            end
        end
    end
end

class InTablePhase < Phase
    # http://www.whatwg.org/specs/web-apps/current-work/#in-table

    handle_start [
        ['html', :startTagHtml],
        ['caption', :startTagCaption],
        ['colgroup', :startTagColgroup],
        ['col', :startTagCol],
        [['tbody', 'tfoot', 'thead'], :startTagRowGroup],
        [['td', 'th', 'tr'], :startTagImplyTbody],
        ['table', :startTagTable]
    ]

    handle_end [
        ['table', :endTagTable],
        [['body', 'caption', 'col', 'colgroup', 'html', 'tbody', 'td', 'tfoot', 'th', 'thead', 'tr'], :endTagIgnore]
    ]

    # helper methods
    def clearStackToTableContext
        # "clear the stack back to a table context"
        until ['table', 'html'].include?(name = @tree.openElements[-1].name)
            @parser.parseError(_("Unexpected implied end tag (#{name}) in the table phase."))
            @tree.openElements.pop
        end
        # When the current node is <html> it's an innerHTML case
    end

    # processing methods
    def processCharacters(data)
        @parser.parseError(_("Unexpected non-space characters in table context caused voodoo mode."))
        # Make all the special element rearranging voodoo kick in
        @tree.insertFromTable = true
        # Process the character in the "in body" mode
        @parser.phases[:inBody].processCharacters(data)
        @tree.insertFromTable = false
    end

    def startTagCaption(name, attributes)
        clearStackToTableContext
        @tree.activeFormattingElements.push(Marker)
        @tree.insertElement(name, attributes)
        @parser.phase = @parser.phases[:inCaption]
    end

    def startTagColgroup(name, attributes)
        clearStackToTableContext
        @tree.insertElement(name, attributes)
        @parser.phase = @parser.phases[:inColumnGroup]
    end

    def startTagCol(name, attributes)
        startTagColgroup('colgroup', {})
        @parser.phase.processStartTag(name, attributes)
    end

    def startTagRowGroup(name, attributes)
        clearStackToTableContext
        @tree.insertElement(name, attributes)
        @parser.phase = @parser.phases[:inTableBody]
    end

    def startTagImplyTbody(name, attributes)
        startTagRowGroup('tbody', {})
        @parser.phase.processStartTag(name, attributes)
    end

    def startTagTable(name, attributes)
        @parser.parseError(_("Unexpected start tag (table) in table phase. Implies end tag (table)."))
        @parser.phase.processEndTag('table')
        @parser.phase.processStartTag(name, attributes) unless @parser.innerHTML
    end

    def startTagOther(name, attributes)
        @parser.parseError(_("Unexpected start tag (#{name}) in table context caused voodoo mode."))
        # Make all the special element rearranging voodoo kick in
        @tree.insertFromTable = true
        # Process the start tag in the "in body" mode
        @parser.phases[:inBody].processStartTag(name, attributes)
        @tree.insertFromTable = false
    end

    def endTagTable(name)
        if in_scope?('table', true)
            @tree.generateImpliedEndTags
            
            unless @tree.openElements[-1].name == 'table'
                @parser.parseError(_("Unexpected end tag (table). Expected end tag (#{@tree.openElements[-1].name})."))
            end
            
            remove_open_elements_until('table')

            @parser.resetInsertionMode
        else
            # innerHTML case
            assert @parser.innerHTML
            @parser.parseError
        end
    end

    def endTagIgnore(name)
        @parser.parseError(_("Unexpected end tag (#{name}). Ignored."))
    end

    def endTagOther(name)
        @parser.parseError(_("Unexpected end tag (#{name}) in table context caused voodoo mode."))
        # Make all the special element rearranging voodoo kick in
        @parser.insertFromTable = true
        # Process the end tag in the "in body" mode
        @parser.phases[:inBody].processEndTag(name)
        @parser.insertFromTable = false
    end
end


class InCaptionPhase < Phase
    # http://www.whatwg.org/specs/web-apps/current-work/#in-caption

    handle_start [
        ['html', :startTagHtml],
        [['caption', 'col', 'colgroup', 'tbody', 'td', 'tfoot', 'th', 'thead', 'tr'], :startTagTableElement]
    ]

    handle_end [
        ['caption', :endTagCaption],
        ['table', :endTagTable],
        [['body', 'col', 'colgroup', 'html', 'tbody', 'td', 'tfoot', 'th', 'thead', 'tr'], :endTagIgnore]
    ]

    def ignoreEndTagCaption
        not in_scope?('caption', true)
    end

    def processCharacters(data)
        @parser.phases[:inBody].processCharacters(data)
    end

    def startTagTableElement(name, attributes)
        @parser.parseError
        #XXX Have to duplicate logic here to find out if the tag is ignored
        ignoreEndTag = ignoreEndTagCaption
        @parser.phase.processEndTag('caption')
        @parser.phase.processStartTag(name, attributes) unless ignoreEndTag
    end

    def startTagOther(name, attributes)
        @parser.phases[:inBody].processStartTag(name, attributes)
    end

    def endTagCaption(name)
        if ignoreEndTagCaption
            # innerHTML case
            assert @parser.innerHTML
            @parser.parseError
        else
            # AT this code is quite similar to endTagTable in "InTable"
            @tree.generateImpliedEndTags

            unless @tree.openElements[-1].name == 'caption'
                @parser.parseError(_("Unexpected end tag (caption). Missing end tags."))
            end

            remove_open_elements_until('caption')

            @tree.clearActiveFormattingElements
            @parser.phase = @parser.phases[:inTable]
        end
    end

    def endTagTable(name)
        @parser.parseError
        ignoreEndTag = ignoreEndTagCaption
        @parser.phase.processEndTag('caption')
        @parser.phase.processEndTag(name) unless ignoreEndTag
    end

    def endTagIgnore(name)
        @parser.parseError(_("Unexpected end tag (#{name}). Ignored."))
    end

    def endTagOther(name)
        @parser.phases[:inBody].processEndTag(name)
    end
end


class InColumnGroupPhase < Phase
    # http://www.whatwg.org/specs/web-apps/current-work/#in-column

    handle_start [
        ['html', :startTagHtml],
        ['col', :startTagCol]
    ]

    handle_end [
        ['colgroup', :endTagColgroup],
        ['col', :endTagCol]
    ]

    def ignoreEndTagColgroup
        @tree.openElements[-1].name == 'html'
    end

    def processCharacters(data)
        ignoreEndTag = ignoreEndTagColgroup
        endTagColgroup("colgroup")
        @parser.phase.processCharacters(data) unless ignoreEndTag
    end

    def startTagCol(name, attributes)
        @tree.insertElement(name, attributes)
        @tree.openElements.pop
    end

    def startTagOther(name, attributes)
        ignoreEndTag = ignoreEndTagColgroup
        endTagColgroup('colgroup')
        @parser.phase.processStartTag(name, attributes) unless ignoreEndTag
    end

    def endTagColgroup(name)
        if ignoreEndTagColgroup
            # innerHTML case
            assert @parser.innerHTML
            @parser.parseError
        else
            @tree.openElements.pop
            @parser.phase = @parser.phases[:inTable]
        end
    end

    def endTagCol(name)
        @parser.parseError(_('Unexpected end tag (col). col has no end tag.'))
    end

    def endTagOther(name)
        ignoreEndTag = ignoreEndTagColgroup
        endTagColgroup('colgroup')
        @parser.phase.processEndTag(name) unless ignoreEndTag
    end
end


class InTableBodyPhase < Phase
    # http://www.whatwg.org/specs/web-apps/current-work/#in-table0

    handle_start [
        ['html', :startTagHtml],
        ['tr', :startTagTr],
        [['td', 'th'], :startTagTableCell],
        [['caption', 'col', 'colgroup', 'tbody', 'tfoot', 'thead'], :startTagTableOther]
    ]

    handle_end [
        [['tbody', 'tfoot', 'thead'], :endTagTableRowGroup],
        ['table', :endTagTable],
        [['body', 'caption', 'col', 'colgroup', 'html', 'td', 'th', 'tr'], :endTagIgnore]
    ]

    # helper methods
    def clearStackToTableBodyContext
        until ['tbody', 'tfoot', 'thead', 'html'].include?(name = @tree.openElements[-1].name)
            @parser.parseError(_("Unexpected implied end tag (#{name}) in the table body phase."))
            @tree.openElements.pop
        end
    end

    # the rest
    def processCharacters(data)
        @parser.phases[:inTable].processCharacters(data)
    end

    def startTagTr(name, attributes)
        clearStackToTableBodyContext
        @tree.insertElement(name, attributes)
        @parser.phase = @parser.phases[:inRow]
    end

    def startTagTableCell(name, attributes)
        @parser.parseError(_("Unexpected table cell start tag (#{name}) in the table body phase."))
        startTagTr('tr', {})
        @parser.phase.processStartTag(name, attributes)
    end

    def startTagTableOther(name, attributes)
        # XXX AT Any ideas on how to share this with endTagTable?
        if in_scope?('tbody', true) or in_scope?('thead', true) or in_scope?('tfoot', true)
            clearStackToTableBodyContext
            endTagTableRowGroup(@tree.openElements[-1].name)
            @parser.phase.processStartTag(name, attributes)
        else
            # innerHTML case
            @parser.parseError
        end
    end

    def startTagOther(name, attributes)
        @parser.phases[:inTable].processStartTag(name, attributes)
    end

    def endTagTableRowGroup(name)
        if in_scope?(name, true)
            clearStackToTableBodyContext
            @tree.openElements.pop
            @parser.phase = @parser.phases[:inTable]
        else
            @parser.parseError(_("Unexpected end tag (#{name}) in the table body phase. Ignored."))
        end
    end

    def endTagTable(name)
        if in_scope?('tbody', true) or in_scope?('thead', true) or in_scope?('tfoot', true)
            clearStackToTableBodyContext
            endTagTableRowGroup(@tree.openElements[-1].name)
            @parser.phase.processEndTag(name)
        else
            # innerHTML case
            @parser.parseError
        end
    end

    def endTagIgnore(name)
        @parser.parseError(_("Unexpected end tag (#{name}) in the table body phase. Ignored."))
    end

    def endTagOther(name)
        @parser.phases[:inTable].processEndTag(name)
    end
end


class InRowPhase < Phase
    # http://www.whatwg.org/specs/web-apps/current-work/#in-row

    handle_start [
        ['html', :startTagHtml],
        [['td', 'th'], :startTagTableCell],
        [['caption', 'col', 'colgroup', 'tbody', 'tfoot', 'thead', 'tr'], :startTagTableOther]
    ]

    handle_end [
        ['tr', :endTagTr],
        ['table', :endTagTable],
        [['tbody', 'tfoot', 'thead'], :endTagTableRowGroup],
        [['body', 'caption', 'col', 'colgroup', 'html', 'td', 'th'], :endTagIgnore]
    ]

    # helper methods (XXX unify this with other table helper methods)
    def clearStackToTableRowContext
        until ['tr', 'html'].include?(name = @tree.openElements[-1].name)
            @parser.parseError(_("Unexpected implied end tag (#{name}) in the row phase."))
            @tree.openElements.pop
        end
    end

    def ignoreEndTagTr
        not in_scope?('tr', :tableVariant => true)
    end

    # the rest
    def processCharacters(data)
        @parser.phases[:inTable].processCharacters(data)
    end

    def startTagTableCell(name, attributes)
        clearStackToTableRowContext
        @tree.insertElement(name, attributes)
        @parser.phase = @parser.phases[:inCell]
        @tree.activeFormattingElements.push(Marker)
    end

    def startTagTableOther(name, attributes)
        ignoreEndTag = ignoreEndTagTr
        endTagTr('tr')
        # XXX how are we sure it's always ignored in the innerHTML case?
        @parser.phase.processStartTag(name, attributes) unless ignoreEndTag
    end

    def startTagOther(name, attributes)
        @parser.phases[:inTable].processStartTag(name, attributes)
    end

    def endTagTr(name)
        if ignoreEndTagTr
            # innerHTML case
            assert @parser.innerHTML
            @parser.parseError
        else
            clearStackToTableRowContext
            @tree.openElements.pop
            @parser.phase = @parser.phases[:inTableBody]
        end
    end

    def endTagTable(name)
        ignoreEndTag = ignoreEndTagTr
        endTagTr('tr')
        # Reprocess the current tag if the tr end tag was not ignored
        # XXX how are we sure it's always ignored in the innerHTML case?
        @parser.phase.processEndTag(name) unless ignoreEndTag
    end

    def endTagTableRowGroup(name)
        if in_scope?(name, true)
            endTagTr('tr')
            @parser.phase.processEndTag(name)
        else
            # innerHTML case
            @parser.parseError
        end
    end

    def endTagIgnore(name)
        @parser.parseError(_("Unexpected end tag (#{name}) in the row phase. Ignored."))
    end

    def endTagOther(name)
        @parser.phases[:inTable].processEndTag(name)
    end
end

class InCellPhase < Phase
    # http://www.whatwg.org/specs/web-apps/current-work/#in-cell

    handle_start [
        ['html', :startTagHtml],
        [['caption', 'col', 'colgroup', 'tbody', 'td', 'tfoot', 'th', 'thead', 'tr'], :startTagTableOther]
    ]

    handle_end [
        [['td', 'th'], :endTagTableCell],
        [['body', 'caption', 'col', 'colgroup', 'html'], :endTagIgnore],
        [['table', 'tbody', 'tfoot', 'thead', 'tr'], :endTagImply]
    ]

    # helper
    def closeCell
        if in_scope?('td', true)
            endTagTableCell('td')
        elsif in_scope?('th', true)
            endTagTableCell('th')
        end
    end

    # the rest
    def processCharacters(data)
        @parser.phases[:inBody].processCharacters(data)
    end

    def startTagTableOther(name, attributes)
        if in_scope?('td', true) or in_scope?('th', true)
            closeCell
            @parser.phase.processStartTag(name, attributes)
        else
            # innerHTML case
            @parser.parseError
        end
    end

    def startTagOther(name, attributes)
        @parser.phases[:inBody].processStartTag(name, attributes)
    end

    def endTagTableCell(name)
        if in_scope?(name, true)
            @tree.generateImpliedEndTags(name)
            if @tree.openElements[-1].name != name
                @parser.parseError("Got table cell end tag (#{name}) while required end tags are missing.")

                remove_open_elements_until(name)
            else
                @tree.openElements.pop
            end
            @tree.clearActiveFormattingElements
            @parser.phase = @parser.phases[:inRow]
        else
            @parser.parseError(_("Unexpected end tag (#{name}). Ignored."))
        end
    end

    def endTagIgnore(name)
        @parser.parseError(_("Unexpected end tag (#{name}). Ignored."))
    end

    def endTagImply(name)
        if in_scope?(name, true)
            closeCell
            @parser.phase.processEndTag(name)
        else
            # sometimes innerHTML case
            @parser.parseError
        end
    end

    def endTagOther(name)
        @parser.phases[:inBody].processEndTag(name)
    end
end


class InSelectPhase < Phase
    # http://www.whatwg.org/specs/web-apps/current-work/#in-select

    handle_start [
        ['html', :startTagHtml],
        ['option', :startTagOption],
        ['optgroup', :startTagOptgroup],
        ['select', :startTagSelect]
    ]

    handle_end [
        ['option', :endTagOption],
        ['optgroup', :endTagOptgroup],
        ['select', :endTagSelect],
        [['caption', 'table', 'tbody', 'tfoot', 'thead', 'tr', 'td', 'th'], :endTagTableElements]
    ]

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


class AfterBodyPhase < Phase

    handle_end [['html', :endTagHtml]]

    def processComment(data)
        # This is needed because data is to be appended to the <html> element
        # here and not to whatever is currently open.
        @tree.insertComment(data, @tree.openElements[0])
    end

    def processCharacters(data)
        @parser.parseError(_('Unexpected non-space characters in the after body phase.'))
        @parser.phase = @parser.phases[:inBody]
        @parser.phase.processCharacters(data)
    end

    def processStartTag(name, attributes)
        @parser.parseError(_("Unexpected start tag token (#{name}) in the after body phase."))
        @parser.phase = @parser.phases[:inBody]
        @parser.phase.processStartTag(name, attributes)
    end

    def endTagHtml(name)
        if @parser.innerHTML
            @parser.parseError
        else
            # XXX: This may need to be done, not sure
            # Don't set lastPhase to the current phase but to the inBody phase
            # instead. No need for extra parse errors if there's something after </html>.
            # Try "<!doctype html>X</html>X" for instance.
            @parser.lastPhase = @parser.phase
            @parser.phase = @parser.phases[:trailingEnd]
        end
    end

    def endTagOther(name)
        @parser.parseError(_("Unexpected end tag token (#{name}) in the after body phase."))
        @parser.phase = @parser.phases[:inBody]
        @parser.phase.processEndTag(name)
    end
end

class InFramesetPhase < Phase
    # http://www.whatwg.org/specs/web-apps/current-work/#in-frameset

    handle_start [
        ['html', :startTagHtml],
        ['frameset', :startTagFrameset],
        ['frame', :startTagFrame],
        ['noframes', :startTagNoframes]
    ]

    handle_end [
        ['frameset', :endTagFrameset],
        ['noframes', :endTagNoframes]
    ]

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


class AfterFramesetPhase < Phase
    # http://www.whatwg.org/specs/web-apps/current-work/#after3

    handle_start [
        ['html', :startTagHtml],
        ['noframes', :startTagNoframes]
    ]

    handle_end [
        ['html', :endTagHtml]
    ]

    def processCharacters(data)
        @parser.parseError(_('Unexpected non-space characters in the after frameset phase. Ignored.'))
    end

    def startTagNoframes(name, attributes)
        @parser.phases[:inBody].processStartTag(name, attributes)
    end

    def startTagOther(name, attributes)
        @parser.parseError(_("Unexpected start tag (#{name}) in the after frameset phase. Ignored."))
    end

    def endTagHtml(name)
        @parser.lastPhase = @parser.phase
        @parser.phase = @parser.phases[:trailingEnd]
    end

    def endTagOther(name)
        @parser.parseError(_("Unexpected end tag (#{name}) in the after frameset phase. Ignored."))
    end
end


class TrailingEndPhase < Phase
    def processEOF
    end

    def processComment(data)
        @tree.insertComment(data, @tree.document)
    end

    def processSpaceCharacters(data)
        @parser.lastPhase.processSpaceCharacters(data)
    end

    def processCharacters(data)
        @parser.parseError(_('Unexpected non-space characters. Expected end of file.'))
        @parser.phase = @parser.lastPhase
        @parser.phase.processCharacters(data)
    end

    def processStartTag(name, attributes)
        @parser.parseError(_('Unexpected start tag (#{name}). Expected end of file.'))
        @parser.phase = @parser.lastPhase
        @parser.phase.processStartTag(name, attributes)
    end

    def processEndTag(name)
        @parser.parseError(_('Unexpected end tag (#{name}). Expected end of file.'))
        @parser.phase = @parser.lastPhase
        @parser.phase.processEndTag(name)
    end
end


# Error in parsed document
class ParseError < Exception; end
class AssertionError < Exception; end

end
