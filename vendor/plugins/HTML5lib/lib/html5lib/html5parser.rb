require 'html5lib/constants'
require 'html5lib/tokenizer'
require 'html5lib/treebuilders/rexml'

Dir.glob(File.join(File.dirname(__FILE__), 'html5parser', '*_phase.rb')).each do |path|
  require 'html5lib/html5parser/' + File.basename(path)
end

module HTML5lib

  # Error in parsed document
  class ParseError < Exception; end
  class AssertionError < Exception; end

  # HTML parser. Generates a tree structure from a stream of (possibly malformed) HTML
  #
  class HTMLParser

    attr_accessor :phase, :firstStartTag, :innerHTML, :lastPhase, :insertFromTable

    attr_reader :phases, :tokenizer, :tree, :errors

    def self.parse(stream, options = {})
      encoding = options.delete(:encoding)
      new(options).parse(stream,encoding)
    end

    def self.parseFragment(stream, options = {})
      container = options.delete(:container) || 'div'
      encoding = options.delete(:encoding)
      new(options).parseFragment(stream,container,encoding)
    end

    @@phases = %w( initial rootElement beforeHead inHead afterHead inBody inTable inCaption
      inColumnGroup inTableBody inRow inCell inSelect afterBody inFrameset afterFrameset trailingEnd )

    # :strict - raise an exception when a parse error is encountered
    # :tree - a treebuilder class controlling the type of tree that will be
    # returned. Built in treebuilders can be accessed through
    # HTML5lib::TreeBuilders[treeType]
    def initialize(options = {})
      @strict = false
      @errors = []
     
      @tokenizer =  HTMLTokenizer
      @tree = TreeBuilders::REXML::TreeBuilder
 
      options.each { |name, value| instance_variable_set("@#{name}", value) }

      @tree = @tree.new

      @phases = @@phases.inject({}) do |phases, phase_name|
        phase_class_name = phase_name.sub(/(.)/) { $1.upcase } + 'Phase'
        phases[phase_name.to_sym] = HTML5lib.const_get(phase_class_name).new(self, @tree)
        phases 
      end
    end

    def _parse(stream, innerHTML, encoding, container = 'div')
      @tree.reset
      @firstStartTag = false
      @errors = []

      @tokenizer = @tokenizer.class unless Class === @tokenizer
      @tokenizer = @tokenizer.new(stream, :encoding => encoding,
        :parseMeta => !innerHTML)

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
          when :StartTag
            @phase.send method, token[:name], token[:data]
          when :EndTag
            @phase.send method, token[:name]
          when :Doctype
            @phase.send method, token[:name], token[:publicId],
              token[:systemId], token[:correct]
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
    def parse(stream, encoding=nil)
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
    def parseFragment(stream, container='div', encoding=nil)
      _parse(stream, true, encoding, container)
      return @tree.getFragment
    end

    def parseError(data = 'XXX ERROR MESSAGE NEEDED')
      # XXX The idea is to make data mandatory.
      @errors.push([@tokenizer.stream.position, data])
      raise ParseError if @strict
    end

    # HTML5 specific normalizations to the token stream
    def normalizeToken(token)

      if token[:type] == :EmptyTag
        # When a solidus (/) is encountered within a tag name what happens
        # depends on whether the current tag name matches that of a void
        # element.  If it matches a void element atheists did the wrong
        # thing and if it doesn't it's wrong for everyone.

        unless VOID_ELEMENTS.include?(token[:name])
          parseError(_('Solidus (/) incorrectly placed in tag.'))
        end

        token[:type] = :StartTag
      end

      if token[:type] == :StartTag
        token[:name] = token[:name].tr(ASCII_UPPERCASE,ASCII_LOWERCASE)

        # We need to remove the duplicate attributes and convert attributes
        # to a dict so that [["x", "y"], ["x", "z"]] becomes {"x": "y"}

        unless token[:data].empty?
          data = token[:data].reverse.map { |attr, value| [attr.tr(ASCII_UPPERCASE, ASCII_LOWERCASE), value] }
          token[:data] = Hash[*data.flatten]
        end

      elsif token[:type] == :EndTag
        parseError(_('End tag contains unexpected attributes.')) unless token[:data].empty?
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

end
