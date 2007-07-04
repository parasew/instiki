require 'html5/constants'
require 'html5/inputstream'

module HTML5

  # This class takes care of tokenizing HTML.
  #
  # * @currentToken
  #   Holds the token that is currently being processed.
  #
  # * @state
  #   Holds a reference to the method to be invoked... XXX
  #
  # * @states
  #   Holds a mapping between states and methods that implement the state.
  #
  # * @stream
  #   Points to HTMLInputStream object.

  class HTMLTokenizer
    attr_accessor :contentModelFlag, :currentToken
    attr_reader :stream

    # XXX need to fix documentation

    def initialize(stream, options = {})
      @stream = HTMLInputStream.new(stream, options)

      @states = {
        :data => :dataState,
        :entityData => :entityDataState,
        :tagOpen => :tagOpenState,
        :closeTagOpen => :closeTagOpenState,
        :tagName => :tagNameState,
        :beforeAttributeName => :beforeAttributeNameState,
        :attributeName => :attributeNameState,
        :afterAttributeName => :afterAttributeNameState,
        :beforeAttributeValue => :beforeAttributeValueState,
        :attributeValueDoubleQuoted => :attributeValueDoubleQuotedState,
        :attributeValueSingleQuoted => :attributeValueSingleQuotedState,
        :attributeValueUnQuoted => :attributeValueUnQuotedState,
        :bogusComment => :bogusCommentState,
        :markupDeclarationOpen => :markupDeclarationOpenState,
        :commentStart => :commentStartState,
        :commentStartDash => :commentStartDashState,
        :comment => :commentState,
        :commentEndDash => :commentEndDashState,
        :commentEnd => :commentEndState,
        :doctype => :doctypeState,
        :beforeDoctypeName => :beforeDoctypeNameState,
        :doctypeName => :doctypeNameState,
        :afterDoctypeName => :afterDoctypeNameState,
        :beforeDoctypePublicIdentifier => :beforeDoctypePublicIdentifierState,
        :doctypePublicIdentifierDoubleQuoted => :doctypePublicIdentifierDoubleQuotedState,
        :doctypePublicIdentifierSingleQuoted => :doctypePublicIdentifierSingleQuotedState,
        :afterDoctypePublicIdentifier => :afterDoctypePublicIdentifierState,
        :beforeDoctypeSystemIdentifier => :beforeDoctypeSystemIdentifierState,
        :doctypeSystemIdentifierDoubleQuoted => :doctypeSystemIdentifierDoubleQuotedState,
        :doctypeSystemIdentifierSingleQuoted => :doctypeSystemIdentifierSingleQuotedState,
        :afterDoctypeSystemIdentifier => :afterDoctypeSystemIdentifierState,
        :bogusDoctype => :bogusDoctypeState
      }

      # Setup the initial tokenizer state
      @contentModelFlag = :PCDATA
      @state = @states[:data]
      @escapeFlag = false
      @lastFourChars = []

      # The current token being created
      @currentToken = nil

      # Tokens to be processed.
      @tokenQueue = []
    end

    # This is where the magic happens.
    #
    # We do our usually processing through the states and when we have a token
    # to return we yield the token which pauses processing until the next token
    # is requested.
    def each
      @tokenQueue = []
      # Start processing. When EOF is reached @state will return false
      # instead of true and the loop will terminate.
      while send @state
        yield :type => :ParseError, :data => @stream.errors.shift until
          @stream.errors.empty?
        yield @tokenQueue.shift until @tokenQueue.empty?
      end
    end

    # Below are various helper functions the tokenizer states use worked out.
  
    # If the next character is a '>', convert the currentToken into
    # an EmptyTag

    def processSolidusInTag

      # We need to consume another character to make sure it's a ">"
      data = @stream.char

      if @currentToken[:type] == :StartTag and data == ">"
        @currentToken[:type] = :EmptyTag
      else
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Solidus (/) incorrectly placed in tag.")})
      end

      # The character we just consumed need to be put back on the stack so it
      # doesn't get lost...
      @stream.unget(data)
    end

    # This function returns either U+FFFD or the character based on the
    # decimal or hexadecimal representation. It also discards ";" if present.
    # If not present @tokenQueue.push({:type => :ParseError}") is invoked.

    def consumeNumberEntity(isHex)

      # XXX More need to be done here. For instance, #13 should prolly be
      # converted to #10 so we don't get \r (#13 is \r right?) in the DOM and
      # such. Thoughts on this appreciated.
      allowed = DIGITS
      radix = 10
      if isHex
        allowed = HEX_DIGITS
        radix = 16
      end

      charStack = []

      # Consume all the characters that are in range while making sure we
      # don't hit an EOF.
      c = @stream.char
      while allowed.include?(c) and c != :EOF
        charStack.push(c)
        c = @stream.char
      end

      # Convert the set of characters consumed to an int.
      charAsInt = charStack.join('').to_i(radix)

      if charAsInt == 13
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Incorrect CR newline entity. Replaced with LF.")})
        charAsInt = 10
      elsif (128..159).include? charAsInt
        # If the integer is between 127 and 160 (so 128 and bigger and 159
        # and smaller) we need to do the "windows trick".
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Entity used with illegal number (windows-1252 reference).")})

        charAsInt = ENTITIES_WINDOWS1252[charAsInt - 128]
      end

      if 0 < charAsInt and charAsInt <= 1114111 and not (55296 <= charAsInt and charAsInt <= 57343)
        char = [charAsInt].pack('U')
      else
        char = [0xFFFD].pack('U')
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Numeric entity represents an illegal codepoint.")})
      end

      # Discard the ; if present. Otherwise, put it back on the queue and
      # invoke parseError on parser.
      if c != ";"
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Numeric entity didn't end with ';'.")})
        @stream.unget(c)
      end

      return char
    end

    def consumeEntity(from_attribute=false)
      char = nil
      charStack = [@stream.char]
      if SPACE_CHARACTERS.include?(charStack[0]) or 
        [:EOF, '<', '&'].include?(charStack[0])
        @stream.unget(charStack)
      elsif charStack[0] == "#"
        # We might have a number entity here.
        charStack += [@stream.char, @stream.char]
        if charStack.include? :EOF
          # If we reach the end of the file put everything up to :EOF
          # back in the queue
          charStack = charStack[0...charStack.index(:EOF)]
          @stream.unget(charStack)
          @tokenQueue.push({:type => :ParseError, :data =>
            _("Numeric entity expected. Got end of file instead.")})
        else
          if charStack[1].downcase == "x" \
            and HEX_DIGITS.include? charStack[2]
            # Hexadecimal entity detected.
            @stream.unget(charStack[2])
            char = consumeNumberEntity(true)
          elsif DIGITS.include? charStack[1]
            # Decimal entity detected.
            @stream.unget(charStack[1..-1])
            char = consumeNumberEntity(false)
          else
            # No number entity detected.
            @stream.unget(charStack)
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Numeric entity expected but none found.")})
          end
        end
      else
        # At this point in the process might have named entity. Entities
        # are stored in the global variable "entities".
        #
        # Consume characters and compare to these to a substring of the
        # entity names in the list until the substring no longer matches.
        filteredEntityList = ENTITIES.keys
        filteredEntityList.reject! {|e| e[0].chr != charStack[0]}
        entityName = nil

        # Try to find the longest entity the string will match to take care
        # of &noti for instance.
        while charStack[-1] != :EOF
          name = charStack.join('')
          if filteredEntityList.any? {|e| e[0...name.length] == name}
            filteredEntityList.reject! {|e| e[0...name.length] != name}
            charStack.push(@stream.char)
          else
            break
          end

          if ENTITIES.include? name
            entityName = name
            break if entityName[-1] == ';'
          end
        end

        if entityName != nil
          char = ENTITIES[entityName]

          # Check whether or not the last character returned can be
          # discarded or needs to be put back.
          if entityName[-1] != ?;
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Named entity didn't end with ';'.")})
          end

          if charStack[-1] != ";" and from_attribute and
             (ASCII_LETTERS.include?(charStack[entityName.length]) or
              DIGITS.include?(charStack[entityName.length]))
            @stream.unget(charStack)
            char = '&'
          else
            @stream.unget(charStack[entityName.length..-1])
          end
        else
          @tokenQueue.push({:type => :ParseError, :data =>
            _("Named entity expected. Got none.")})
          @stream.unget(charStack)
        end
      end
      return char
    end

    # This method replaces the need for "entityInAttributeValueState".
    def processEntityInAttribute
      entity = consumeEntity(true)
      if entity
        @currentToken[:data][-1][1] += entity
      else
        @currentToken[:data][-1][1] += "&"
      end
    end

    # This method is a generic handler for emitting the tags. It also sets
    # the state to "data" because that's what's needed after a token has been
    # emitted.
    def emitCurrentToken
      # Add token to the queue to be yielded
      @tokenQueue.push(@currentToken)
      @state = @states[:data]
    end

    # Below are the various tokenizer states worked out.

    # XXX AT Perhaps we should have Hixie run some evaluation on billions of
    # documents to figure out what the order of the various if and elsif
    # statements should be.
    def dataState
      data = @stream.char

      if @contentModelFlag == :CDATA or @contentModelFlag == :RCDATA
        @lastFourChars << data
        @lastFourChars.shift if @lastFourChars.length > 4
      end

      if data == "&" and !@escapeFlag and
        [:PCDATA,:RCDATA].include?(@contentModelFlag)
          @state = @states[:entityData]

      elsif data == "-" and !@escapeFlag and
        [:CDATA,:RCDATA].include?(@contentModelFlag) and
        @lastFourChars.join('') == "<!--"
          @escapeFlag = true
          @tokenQueue.push({:type => :Characters, :data => data})

      elsif data == "<" and !@escapeFlag and
        [:PCDATA,:CDATA,:RCDATA].include?(@contentModelFlag)
          @state = @states[:tagOpen]

      elsif data == ">" and @escapeFlag and 
        [:CDATA,:RCDATA].include?(@contentModelFlag) and
        @lastFourChars[1..-1].join('') == "-->"
          @escapeFlag = false
          @tokenQueue.push({:type => :Characters, :data => data})

      elsif data == :EOF
        # Tokenization ends.
        return false

      elsif SPACE_CHARACTERS.include? data
        # Directly after emitting a token you switch back to the "data
        # state". At that point SPACE_CHARACTERS are important so they are
        # emitted separately.
        # XXX need to check if we don't need a special "spaces" flag on
        # characters.
        @tokenQueue.push({:type => :SpaceCharacters, :data =>
          data + @stream.chars_until(SPACE_CHARACTERS, true)})
      else
        @tokenQueue.push({:type => :Characters, :data => 
          data + @stream.chars_until(%w[& < > -])})
      end
      return true
    end

    def entityDataState
      entity = consumeEntity
      if entity
        @tokenQueue.push({:type => :Characters, :data => entity})
      else
        @tokenQueue.push({:type => :Characters, :data => "&"})
      end
      @state = @states[:data]
      return true
    end

    def tagOpenState
      data = @stream.char
      if @contentModelFlag == :PCDATA
        if data == "!"
          @state = @states[:markupDeclarationOpen]
        elsif data == "/"
          @state = @states[:closeTagOpen]
        elsif data != :EOF and ASCII_LETTERS.include? data
          @currentToken =\
            {:type => :StartTag, :name => data, :data => []}
          @state = @states[:tagName]
        elsif data == ">"
          # XXX In theory it could be something besides a tag name. But
          # do we really care?
          @tokenQueue.push({:type => :ParseError, :data =>
            _("Expected tag name. Got '>' instead.")})
          @tokenQueue.push({:type => :Characters, :data => "<>"})
          @state = @states[:data]
        elsif data == "?"
          # XXX In theory it could be something besides a tag name. But
          # do we really care?
          @tokenQueue.push({:type => :ParseError, :data =>
            _("Expected tag name. Got '?' instead (HTML doesn't " +
            "support processing instructions).")})
          @stream.unget(data)
          @state = @states[:bogusComment]
        else
          # XXX
          @tokenQueue.push({:type => :ParseError, :data =>
            _("Expected tag name. Got something else instead")})
          @tokenQueue.push({:type => :Characters, :data => "<"})
          @stream.unget(data)
          @state = @states[:data]
        end
      else
        # We know the content model flag is set to either RCDATA or CDATA
        # now because this state can never be entered with the PLAINTEXT
        # flag.
        if data == "/"
          @state = @states[:closeTagOpen]
        else
          @tokenQueue.push({:type => :Characters, :data => "<"})
          @stream.unget(data)
          @state = @states[:data]
        end
      end
      return true
    end

    def closeTagOpenState
      if (@contentModelFlag == :RCDATA or @contentModelFlag == :CDATA)
        if @currentToken
          charStack = []

          # So far we know that "</" has been consumed. We now need to know
          # whether the next few characters match the name of last emitted
          # start tag which also happens to be the currentToken. We also need
          # to have the character directly after the characters that could
          # match the start tag name.
          (@currentToken[:name].length + 1).times do
            charStack.push(@stream.char)
            # Make sure we don't get hit by :EOF
            break if charStack[-1] == :EOF
          end

          # Since this is just for checking. We put the characters back on
          # the stack.
          @stream.unget(charStack)
        end

        if @currentToken and
          @currentToken[:name].downcase == 
          charStack[0...-1].join('').downcase and
          (SPACE_CHARACTERS + [">", "/", "<", :EOF]).include? charStack[-1]
          # Because the characters are correct we can safely switch to
          # PCDATA mode now. This also means we don't have to do it when
          # emitting the end tag token.
          @contentModelFlag = :PCDATA
        else
          @tokenQueue.push({:type => :Characters, :data => "</"})
          @state = @states[:data]

          # Need to return here since we don't want the rest of the
          # method to be walked through.
          return true
        end
      end

      data = @stream.char
      if data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Expected closing tag. Unexpected end of file.")})
        @tokenQueue.push({:type => :Characters, :data => "</"})
        @state = @states[:data]
      elsif ASCII_LETTERS.include? data
        @currentToken = {:type => :EndTag, :name => data, :data => []}
        @state = @states[:tagName]
      elsif data == ">"
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Expected closing tag. Got '>' instead. Ignoring '</>'.")})
        @state = @states[:data]
      else
        # XXX data can be _'_...
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Expected closing tag. Unexpected character '#{data}' found.")})
        @stream.unget(data)
        @state = @states[:bogusComment]
      end

      return true
    end

    def tagNameState
      data = @stream.char
      if SPACE_CHARACTERS.include? data
        @state = @states[:beforeAttributeName]
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file in the tag name.")})
        emitCurrentToken
      elsif ASCII_LETTERS.include? data
        @currentToken[:name] += data +\
          @stream.chars_until(ASCII_LETTERS, true)
      elsif data == ">"
        emitCurrentToken
      elsif data == "/"
        processSolidusInTag
        @state = @states[:beforeAttributeName]
      else
        @currentToken[:name] += data
      end
      return true
    end

    def beforeAttributeNameState
      data = @stream.char
      if SPACE_CHARACTERS.include? data
        @stream.chars_until(SPACE_CHARACTERS, true)
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file. Expected attribute name instead.")})
        emitCurrentToken
      elsif ASCII_LETTERS.include? data
        @currentToken[:data].push([data, ""])
        @state = @states[:attributeName]
      elsif data == ">"
        emitCurrentToken
      elsif data == "/"
        processSolidusInTag
      else
        @currentToken[:data].push([data, ""])
        @state = @states[:attributeName]
      end
      return true
    end

    def attributeNameState
      data = @stream.char
      leavingThisState = true
      if data == "="
        @state = @states[:beforeAttributeValue]
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file in attribute name.")})
        emitCurrentToken
        leavingThisState = false
      elsif ASCII_LETTERS.include? data
        @currentToken[:data][-1][0] += data +\
          @stream.chars_until(ASCII_LETTERS, true)
        leavingThisState = false
      elsif data == ">"
        # XXX If we emit here the attributes are converted to a dict
        # without being checked and when the code below runs we error
        # because data is a dict not a list
      elsif SPACE_CHARACTERS.include? data
        @state = @states[:afterAttributeName]
      elsif data == "/"
        processSolidusInTag
        @state = @states[:beforeAttributeName]
      else
        @currentToken[:data][-1][0] += data
        leavingThisState = false
      end

      if leavingThisState
        # Attributes are not dropped at this stage. That happens when the
        # start tag token is emitted so values can still be safely appended
        # to attributes, but we do want to report the parse error in time.
        @currentToken[:data][0...-1].each {|name,value|
          if @currentToken[:data][-1][0] == name
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Dropped duplicate attribute on tag.")})
          end
        }
        # XXX Fix for above XXX
        if data == ">"
          emitCurrentToken
        end
      end
      return true
    end

    def afterAttributeNameState
      data = @stream.char
      if SPACE_CHARACTERS.include? data
        @stream.chars_until(SPACE_CHARACTERS, true)
      elsif data == "="
        @state = @states[:beforeAttributeValue]
      elsif data == ">"
        emitCurrentToken
      elsif ASCII_LETTERS.include? data
        @currentToken[:data].push([data, ""])
        @state = @states[:attributeName]
      elsif data == "/"
        processSolidusInTag
        @state = @states[:beforeAttributeName]
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file. Expected = or end of tag.")})
        emitCurrentToken
      else
        @currentToken[:data].push([data, ""])
        @state = @states[:attributeName]
      end
      return true
    end

    def beforeAttributeValueState
      data = @stream.char
      if SPACE_CHARACTERS.include? data
        @stream.chars_until(SPACE_CHARACTERS, true)
      elsif data == "\""
        @state = @states[:attributeValueDoubleQuoted]
      elsif data == "&"
        @state = @states[:attributeValueUnQuoted]
        @stream.unget(data);
      elsif data == "'"
        @state = @states[:attributeValueSingleQuoted]
      elsif data == ">"
        emitCurrentToken
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file. Expected attribute value.")})
        emitCurrentToken
      else
        @currentToken[:data][-1][1] += data
        @state = @states[:attributeValueUnQuoted]
      end
      return true
    end

    def attributeValueDoubleQuotedState
      data = @stream.char
      if data == "\""
        @state = @states[:beforeAttributeName]
      elsif data == "&"
        processEntityInAttribute
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file in attribute value (\").")})
        emitCurrentToken
      else
        @currentToken[:data][-1][1] += data +\
          @stream.chars_until(["\"", "&"])
      end
      return true
    end

    def attributeValueSingleQuotedState
      data = @stream.char
      if data == "'"
        @state = @states[:beforeAttributeName]
      elsif data == "&"
        processEntityInAttribute
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file in attribute value (').")})
        emitCurrentToken
      else
        @currentToken[:data][-1][1] += data +\
          @stream.chars_until(["'", "&"])
      end
      return true
    end

    def attributeValueUnQuotedState
      data = @stream.char
      if SPACE_CHARACTERS.include? data
        @state = @states[:beforeAttributeName]
      elsif data == "&"
        processEntityInAttribute
      elsif data == ">"
        emitCurrentToken
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file in attribute value.")})
        emitCurrentToken
      else
        @currentToken[:data][-1][1] += data + 
          @stream.chars_until(["&", ">","<"] + SPACE_CHARACTERS)
      end
      return true
    end

    def bogusCommentState
      # Make a new comment token and give it as value all the characters
      # until the first > or :EOF (chars_until checks for :EOF automatically)
      # and emit it.
      @tokenQueue.push(
        {:type => :Comment, :data => @stream.chars_until((">"))})

      # Eat the character directly after the bogus comment which is either a
      # ">" or an :EOF.
      @stream.char
      @state = @states[:data]
      return true
    end

    def markupDeclarationOpenState
      charStack = [@stream.char, @stream.char]
      if charStack == ["-", "-"]
        @currentToken = {:type => :Comment, :data => ""}
        @state = @states[:commentStart]
      else
        5.times { charStack.push(@stream.char) }
        # Put in explicit :EOF check
        if ((not charStack.include? :EOF) and
          charStack.join("").upcase == "DOCTYPE")
          @currentToken =\
            {:type => :Doctype, :name => "",
             :publicId => nil, :systemId => nil, :correct => true}
          @state = @states[:doctype]
        else
          @tokenQueue.push({:type => :ParseError, :data =>
            _("Expected '--' or 'DOCTYPE'. Not found.")})
          @stream.unget(charStack)
          @state = @states[:bogusComment]
        end
      end
      return true
    end

    def commentStartState
        data = @stream.char
        if data == "-"
            @state = @states[:commentStartDash]
        elsif data == ">"
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Incorrect comment.")})
            @tokenQueue.push(@currentToken)
            @state = @states[:data]
        elsif data == EOF
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Unexpected end of file in comment.")})
            @tokenQueue.push(@currentToken)
            @state = @states[:data]
        else
            @currentToken[:data] += data + @stream.chars_until("-")
            @state = @states[:comment]
        end
        return true
    end
    
    def commentStartDashState
        data = @stream.char
        if data == "-"
            @state = @states[:commentEnd]
        elsif data == ">"
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Incorrect comment.")})
            @tokenQueue.push(@currentToken)
            @state = @states[:data]
        elsif data == EOF
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Unexpected end of file in comment.")})
            @tokenQueue.push(@currentToken)
            @state = @states[:data]
        else
            @currentToken[:data] += data + @stream.chars_until("-")
            @state = @states[:comment]
        end
        return true
    end

    def commentState
      data = @stream.char
      if data == "-"
        @state = @states[:commentEndDash]
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file in comment.")})
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      else
        @currentToken[:data] += data + @stream.chars_until("-")
      end
      return true
    end

    def commentEndDashState
      data = @stream.char
      if data == "-"
        @state = @states[:commentEnd]
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file in comment (-)")})
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      else
        @currentToken[:data] += "-" + data +\
          @stream.chars_until("-")
        # Consume the next character which is either a "-" or an :EOF as
        # well so if there's a "-" directly after the "-" we go nicely to
        # the "comment end state" without emitting a ParseError there.
        @stream.char
      end
      return true
    end

    def commentEndState
      data = @stream.char
      if data == ">"
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      elsif data == "-"
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected '-' after '--' found in comment.")})
        @currentToken[:data] += data
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file in comment (--).")})
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      else
        # XXX
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected character in comment found.")})
        @currentToken[:data] += "--" + data
        @state = @states[:comment]
      end
      return true
    end

    def doctypeState
      data = @stream.char
      if SPACE_CHARACTERS.include? data
        @state = @states[:beforeDoctypeName]
      else
        @tokenQueue.push({:type => :ParseError, :data =>
          _("No space after literal string 'DOCTYPE'.")})
        @stream.unget(data)
        @state = @states[:beforeDoctypeName]
      end
      return true
    end

    def beforeDoctypeNameState
      data = @stream.char
      if SPACE_CHARACTERS.include? data
      elsif data == ">"
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected > character. Expected DOCTYPE name.")})
        @currentToken[:correct] = false
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file. Expected DOCTYPE name.")})
        @currentToken[:correct] = false
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      else
        @currentToken[:name] = data
        @state = @states[:doctypeName]
      end
      return true
    end

    def doctypeNameState
      data = @stream.char
      if SPACE_CHARACTERS.include? data
        @state = @states[:afterDoctypeName]
      elsif data == ">"
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file in DOCTYPE name.")})
        @currentToken[:correct] = false
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      else
        @currentToken[:name] += data
      end

      return true
    end

    def afterDoctypeNameState
      data = @stream.char
      if SPACE_CHARACTERS.include? data
      elsif data == ">"
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      elsif data == :EOF
        @currentToken[:data] = true
        @stream.unget(data)
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file in DOCTYPE.")})
        @currentToken[:correct] = false
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      else
        charStack = [data]  
        5.times { charStack << stream.char }
        token = charStack.join('').tr(ASCII_UPPERCASE,ASCII_LOWERCASE)
        if token == "public"
          @state = @states[:beforeDoctypePublicIdentifier]
        elsif token == "system"
          @state = @states[:beforeDoctypeSystemIdentifier]
        else
          @stream.unget(charStack)
          @tokenQueue.push({:type => :ParseError, :data =>
            _("Expected 'public' or 'system'. Got '#{charStack.join('')}'")})
          @state = @states[:bogusDoctype]
        end
      end
      return true
    end
    
    def beforeDoctypePublicIdentifierState
      data = @stream.char

      if SPACE_CHARACTERS.include?(data)
      elsif data == "\""
        @currentToken[:publicId] = ""
        @state = @states[:doctypePublicIdentifierDoubleQuoted]
      elsif data == "'"
        @currentToken[:publicId] = ""
        @state = @states[:doctypePublicIdentifierSingleQuoted]
      elsif data == ">"
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of DOCTYPE.")})
        @currentToken[:correct] = false
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file in DOCTYPE.")})
        @currentToken[:correct] = false
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      else
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected character in DOCTYPE.")})
        @state = @states[:bogusDoctype]
      end

      return true
    end
 
    def doctypePublicIdentifierDoubleQuotedState
      data = @stream.char
      if data == "\""
        @state = @states[:afterDoctypePublicIdentifier]
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file in DOCTYPE.")})
        @currentToken[:correct] = false
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      else
        @currentToken[:publicId] += data
      end
      return true
    end

    def doctypePublicIdentifierSingleQuotedState
      data = @stream.char
      if data == "'"
        @state = @states[:afterDoctypePublicIdentifier]
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file in DOCTYPE.")})
        @currentToken[:correct] = false
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      else
        @currentToken[:publicId] += data
      end
      return true
    end

    def afterDoctypePublicIdentifierState
      data = @stream.char
      if SPACE_CHARACTERS.include?(data)
      elsif data == "\""
        @currentToken[:systemId] = ""
        @state = @states[:doctypeSystemIdentifierDoubleQuoted]
      elsif data == "'"
        @currentToken[:systemId] = ""
        @state = @states[:doctypeSystemIdentifierSingleQuoted]
      elsif data == ">"
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file in DOCTYPE.")})
        @currentToken[:correct] = false
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      else
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected character in DOCTYPE.")})
        @state = @states[:bogusDoctype]
      end
      return true
    end
    
    def beforeDoctypeSystemIdentifierState
      data = @stream.char
      if SPACE_CHARACTERS.include?(data)
      elsif data == "\""
        @currentToken[:systemId] = ""
        @state = @states[:doctypeSystemIdentifierDoubleQuoted]
      elsif data == "'"
        @currentToken[:systemId] = ""
        @state = @states[:doctypeSystemIdentifierSingleQuoted]
      elsif data == ">"
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected character in DOCTYPE.")})
        @currentToken[:correct] = false
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file in DOCTYPE.")})
        @currentToken[:correct] = false
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      else
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected character in DOCTYPE.")})
        @state = @states[:bogusDoctype]
      end
      return true
    end

    def doctypeSystemIdentifierDoubleQuotedState
      data = @stream.char
      if data == "\""
        @state = @states[:afterDoctypeSystemIdentifier]
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file in DOCTYPE.")})
        @currentToken[:correct] = false
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      else
        @currentToken[:systemId] += data
      end
      return true
    end

    def doctypeSystemIdentifierSingleQuotedState
      data = @stream.char
      if data == "'"
        @state = @states[:afterDoctypeSystemIdentifier]
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file in DOCTYPE.")})
        @currentToken[:correct] = false
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      else
        @currentToken[:systemId] += data
      end
      return true
    end

    def afterDoctypeSystemIdentifierState
      data = @stream.char
      if SPACE_CHARACTERS.include?(data)
      elsif data == ">"
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      elsif data == :EOF
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file in DOCTYPE.")})
        @currentToken[:correct] = false
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      else
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected character in DOCTYPE.")})
        @state = @states[:bogusDoctype]
      end
      return true
    end

    def bogusDoctypeState
      data = @stream.char
      if data == ">"
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      elsif data == :EOF
        # XXX EMIT
        @stream.unget(data)
        @tokenQueue.push({:type => :ParseError, :data =>
          _("Unexpected end of file in bogus doctype.")})
        @currentToken[:correct] = false
        @tokenQueue.push(@currentToken)
        @state = @states[:data]
      end
      return true
    end

    def _(string); string; end
  end

end
