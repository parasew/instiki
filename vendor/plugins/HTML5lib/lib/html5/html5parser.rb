require 'html5/constants'
require 'html5/tokenizer'
require 'html5/treebuilders/rexml'

Dir.glob(File.join(File.dirname(__FILE__), 'html5parser', '*_phase.rb')).each do |path|
  require 'html5/html5parser/' + File.basename(path)
end

module HTML5

  # Error in parsed document
  class ParseError < Exception; end
  class AssertionError < Exception; end

  # HTML parser. Generates a tree structure from a stream of (possibly malformed) HTML
  #
  class HTMLParser

    attr_accessor :phase, :first_start_tag, :inner_html, :last_phase, :insert_from_table

    attr_reader :phases, :tokenizer, :tree, :errors

    def self.parse(stream, options = {})
      encoding = options.delete(:encoding)
      new(options).parse(stream,encoding)
    end

    def self.parse_fragment(stream, options = {})
      container = options.delete(:container) || 'div'
      encoding = options.delete(:encoding)
      new(options).parse_fragment(stream, container, encoding)
    end

    @@phases = %w( initial rootElement beforeHead inHead afterHead inBody inTable inCaption
      inColumnGroup inTableBody inRow inCell inSelect afterBody inFrameset afterFrameset trailingEnd )

    # :strict - raise an exception when a parse error is encountered
    # :tree - a treebuilder class controlling the type of tree that will be
    # returned. Built in treebuilders can be accessed through
    # HTML5::TreeBuilders[treeType]
    def initialize(options = {})
      @strict = false
      @errors = []
     
      @tokenizer =  HTMLTokenizer
      @tree = TreeBuilders::REXML::TreeBuilder

      options.each {|name, value| instance_variable_set("@#{name}", value) }
      @lowercase_attr_name    = nil unless instance_variable_defined?("@lowercase_attr_name")
      @lowercase_element_name = nil unless instance_variable_defined?("@lowercase_element_name")

      @tree = @tree.new

      @phases = @@phases.inject({}) do |phases, phase_name|
        phase_class_name = phase_name.sub(/(.)/) { $1.upcase } + 'Phase'
        phases[phase_name.to_sym] = HTML5.const_get(phase_class_name).new(self, @tree)
        phases
      end
    end

    def _parse(stream, inner_html, encoding, container = 'div')
      @tree.reset
      @first_start_tag = false
      @errors = []

      @tokenizer = @tokenizer.class unless Class === @tokenizer
      @tokenizer = @tokenizer.new(stream, :encoding => encoding,
        :parseMeta => !inner_html, :lowercase_attr_name => @lowercase_attr_name, :lowercase_element_name => @lowercase_element_name)

      if inner_html
        case @inner_html = container.downcase
        when 'title', 'textarea'
          @tokenizer.content_model_flag = :RCDATA
        when 'style', 'script', 'xmp', 'iframe', 'noembed', 'noframes', 'noscript'
          @tokenizer.content_model_flag = :CDATA
        when 'plaintext'
          @tokenizer.content_model_flag = :PLAINTEXT
        else
          # content_model_flag already is PCDATA
          @tokenizer.content_model_flag = :PCDATA
        end
      
        @phase = @phases[:rootElement]
        @phase.insert_html_element
        reset_insertion_mode
      else
        @inner_html = false
        @phase = @phases[:initial]
      end

      # We only seem to have InBodyPhase testcases where the following is
      # relevant ... need others too
      @last_phase = nil

      # XXX This is temporary for the moment so there isn't any other
      # changes needed for the parser to work with the iterable tokenizer
      @tokenizer.each do |token|
        token = normalize_token(token)

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
          parse_error(token[:data], token[:datavars])
        end
      end

      # When the loop finishes it's EOF
      @phase.process_eof
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
      @tree.get_document
    end

    # Parse a HTML fragment into a well-formed tree fragment

    # container - name of the element we're setting the inner_html property
    # if set to nil, default to 'div'
    #
    # stream - a filelike object or string containing the HTML to be parsed
    #
    # The optional encoding parameter must be a string that indicates
    # the encoding.  If specified, that encoding will be used,
    # regardless of any BOM or later declaration (such as in a meta
    # element)
    def parse_fragment(stream, container='div', encoding=nil)
      _parse(stream, true, encoding, container)
      @tree.get_fragment
    end

    def parse_error(code = 'XXX-undefined-error', data = {})
      # XXX The idea is to make data mandatory.
      @errors.push([@tokenizer.stream.position, code, data])
      raise ParseError if @strict
    end

    # HTML5 specific normalizations to the token stream
    def normalize_token(token)

      if token[:type] == :EmptyTag
        # When a solidus (/) is encountered within a tag name what happens
        # depends on whether the current tag name matches that of a void
        # element.  If it matches a void element atheists did the wrong
        # thing and if it doesn't it's wrong for everyone.

        unless VOID_ELEMENTS.include?(token[:name])
          parse_error("incorrectly-placed-solidus")
        end

        token[:type] = :StartTag
      end

      if token[:type] == :StartTag
        token[:name] = token[:name].downcase

        # We need to remove the duplicate attributes and convert attributes
        # to a dict so that [["x", "y"], ["x", "z"]] becomes {"x": "y"}

        unless token[:data].empty?
          data = token[:data].reverse.map {|attr, value| [attr.downcase, value] }
          token[:data] = Hash[*data.flatten]
        end

      elsif token[:type] == :EndTag
        parse_error("attributes-in-end-tag") unless token[:data].empty?
        token[:name] = token[:name].downcase
      end

      token
    end

    @@new_modes = {
      'select'   => :inSelect,
      'td'       => :inCell,
      'th'       => :inCell,
      'tr'       => :inRow,
      'tbody'    => :inTableBody,
      'thead'    => :inTableBody,
      'tfoot'    => :inTableBody,
      'caption'  => :inCaption,
      'colgroup' => :inColumnGroup,
      'table'    => :inTable,
      'head'     => :inBody,
      'body'     => :inBody,
      'frameset' => :inFrameset
    }

    def reset_insertion_mode
      # The name of this method is mostly historical. (It's also used in the
      # specification.)
      last = false

      @tree.open_elements.reverse.each do |node|
        node_name = node.name

        if node == @tree.open_elements.first
          last = true
          unless ['td', 'th'].include?(node_name)
            # XXX
            # assert @inner_html
            node_name = @inner_html
          end
        end

        # Check for conditions that should only happen in the inner_html
        # case
        if ['select', 'colgroup', 'head', 'frameset'].include?(node_name)
          # XXX
          # assert @inner_html
        end

        if @@new_modes.has_key?(node_name)
          @phase = @phases[@@new_modes[node_name]]
        elsif node_name == 'html'
          @phase = @phases[@tree.head_pointer.nil?? :beforeHead : :afterHead]
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
