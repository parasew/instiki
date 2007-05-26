require 'html5lib/constants'
require 'html5lib/inputstream'

module HTML5lib

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

    def initialize(stream, options={})
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
            :comment => :commentState,
            :commentDash => :commentDashState,
            :commentEnd => :commentEndState,
            :doctype => :doctypeState,
            :beforeDoctypeName => :beforeDoctypeNameState,
            :doctypeName => :doctypeNameState,
            :afterDoctypeName => :afterDoctypeNameState,
            :bogusDoctype => :bogusDoctypeState
        }

        # Setup the initial tokenizer state
        @contentModelFlag = :PCDATA
        @state = @states[:data]

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
        @stream.reset
        @tokenQueue = []
        # Start processing. When EOF is reached @state will return false
        # instead of true and the loop will terminate.
        while send @state
            while not @tokenQueue.empty?
                yield @tokenQueue.shift
            end
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
        @stream.queue.push(data)
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

        char = [0xFFFD].pack('U')
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

        # If the integer is between 127 and 160 (so 128 and bigger and 159 and
        # smaller) we need to do the "windows trick".
        if (127...160).include? charAsInt
            #XXX - removed parse error from windows 1252 entity for now
            #we may want to reenable this later
            #@tokenQueue.push({:type => :ParseError, :data =>
            #  _("Entity used with illegal number (windows-1252 reference).")})

            charAsInt = ENTITIES_WINDOWS1252[charAsInt - 128]
        end

        # 0 is not a good number.
        if charAsInt == 0
            charAsInt = 65533
        end

        if charAsInt <= 0x10FFF
            char = [charAsInt].pack('U')
        else
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Numeric entity couldn't be converted to character.")})
        end

        # Discard the ; if present. Otherwise, put it back on the queue and
        # invoke parseError on parser.
        if c != ";"
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Numeric entity didn't end with ';'.")})
            @stream.queue.push(c)
        end

        return char
    end

    def consumeEntity
        char = nil
        charStack = [@stream.char]
        if charStack[0] == "#"
            # We might have a number entity here.
            charStack += [@stream.char, @stream.char]
            if charStack.include? :EOF
                # If we reach the end of the file put everything up to :EOF
                # back in the queue
                charStack = charStack[0...charStack.index(:EOF)]
                @stream.queue+= charStack
                @tokenQueue.push({:type => :ParseError, :data =>
                  _("Numeric entity expected. Got end of file instead.")})
            else
                if charStack[1].downcase == "x" \
                  and HEX_DIGITS.include? charStack[2]
                    # Hexadecimal entity detected.
                    @stream.queue.push(charStack[2])
                    char = consumeNumberEntity(true)
                elsif DIGITS.include? charStack[1]
                    # Decimal entity detected.
                    @stream.queue += charStack[1..-1]
                    char = consumeNumberEntity(false)
                else
                    # No number entity detected.
                    @stream.queue += charStack
                    @tokenQueue.push({:type => :ParseError, :data =>
                      _("Numeric entity expected but none found.")})
                end
            end
        # Break out if we reach the end of the file
        elsif charStack[0] == :EOF
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Entity expected. Got end of file instead.")})
        else
            # At this point in the process might have named entity. Entities
            # are stored in the global variable "entities".
            #
            # Consume characters and compare to these to a substring of the
            # entity names in the list until the substring no longer matches.
            filteredEntityList = ENTITIES.keys
            filteredEntityList.reject! {|e| e[0].chr != charStack[0]}
            entityName = nil

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
                end
            end

            if entityName != nil
                char = ENTITIES[entityName]

                # Check whether or not the last character returned can be
                # discarded or needs to be put back.
                if not charStack[-1] == ";"
                    @tokenQueue.push({:type => :ParseError, :data =>
                      _("Named entity didn't end with ';'.")})
                    @stream.queue += charStack[entityName.length..-1]
                end
            else
                @tokenQueue.push({:type => :ParseError, :data =>
                  _("Named entity expected. Got none.")})
                @stream.queue += charStack
            end
        end
        return char
    end

    # This method replaces the need for "entityInAttributeValueState".
    def processEntityInAttribute
        entity = consumeEntity
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
        if data == "&" and (@contentModelFlag == :PCDATA or
            @contentModelFlag == :RCDATA)
            @state = @states[:entityData]
        elsif data == "<" and @contentModelFlag != :PLAINTEXT
            @state = @states[:tagOpen]
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
              data + @stream.charsUntil(SPACE_CHARACTERS, true)})
        else
            @tokenQueue.push({:type => :Characters, :data => 
              data + @stream.charsUntil(["&", "<"])})
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
                @stream.queue.push(data)
                @state = @states[:bogusComment]
            else
                # XXX
                @tokenQueue.push({:type => :ParseError, :data =>
                  _("Expected tag name. Got something else instead")})
                @tokenQueue.push({:type => :Characters, :data => "<"})
                @stream.queue.push(data)
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
                @stream.queue.insert(0, data)
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
                @stream.queue += charStack
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
                @tokenQueue.push({:type => :ParseError, :data =>
                  _("Expected closing tag after seeing '</'. None found.")})
                @tokenQueue.push({:type => :Characters, :data => "</"})
                @state = @states[:data]

                # Need to return here since we don't want the rest of the
                # method to be walked through.
                return true
            end
        end

        if @contentModelFlag == :PCDATA
            data = @stream.char
            if data == :EOF
                @tokenQueue.push({:type => :ParseError, :data =>
                  _("Expected closing tag. Unexpected end of file.")})
                @tokenQueue.push({:type => :Characters, :data => "</"})
                @state = @states[:data]
            elsif ASCII_LETTERS.include? data
                @currentToken =\
                  {:type => :EndTag, :name => data, :data => []}
                @state = @states[:tagName]
            elsif data == ">"
                @tokenQueue.push({:type => :ParseError, :data =>
                  _("Expected closing tag. Got '>' instead. Ignoring '</>'.")})
                @state = @states[:data]
            else
                # XXX data can be _'_...
                @tokenQueue.push({:type => :ParseError, :data =>
                  _("Expected closing tag. Unexpected character '" + data + "' found.")})
                @stream.queue.push(data)
                @state = @states[:bogusComment]
            end
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
              @stream.charsUntil(ASCII_LETTERS, true)
        elsif data == ">"
            emitCurrentToken
        elsif data == "<"
            @stream.queue.push(data)
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Unexpected < character when getting the tag name.")})
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
            @stream.charsUntil(SPACE_CHARACTERS, true)
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
        elsif data == "<"
            @stream.queue.push(data)
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Unexpected < character. Expected attribute name instead.")})
            emitCurrentToken
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
              @stream.charsUntil(ASCII_LETTERS, true)
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
        elsif data == "<"
            @stream.queue.push(data)
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Unexpected < character in attribute name.")})
            emitCurrentToken
            leavingThisState = false
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
            @stream.charsUntil(SPACE_CHARACTERS, true)
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
        elsif data == "<"
            @stream.queue.push(data)
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Unexpected < character. Expected = or end of tag.")})
            emitCurrentToken
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
            @stream.charsUntil(SPACE_CHARACTERS, true)
        elsif data == "\""
            @state = @states[:attributeValueDoubleQuoted]
        elsif data == "&"
            @state = @states[:attributeValueUnQuoted]
            @stream.queue.push(data);
        elsif data == "'"
            @state = @states[:attributeValueSingleQuoted]
        elsif data == ">"
            emitCurrentToken
        elsif data == "<"
            @stream.queue.push(data)
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Unexpected < character. Expected attribute value.")})
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
              @stream.charsUntil(["\"", "&"])
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
              @stream.charsUntil(["'", "&"])
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
        elsif data == "<"
            @stream.queue.push(data)
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Unexpected < character in attribute value.")})
            emitCurrentToken
        elsif data == :EOF
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Unexpected end of file in attribute value.")})
            emitCurrentToken
        else
            @currentToken[:data][-1][1] += data + 
              @stream.charsUntil(["&", ">","<"] + SPACE_CHARACTERS)
        end
        return true
    end

    def bogusCommentState
        # Make a new comment token and give it as value all the characters
        # until the first > or :EOF (charsUntil checks for :EOF automatically)
        # and emit it.
        @tokenQueue.push(
          {:type => :Comment, :data => @stream.charsUntil((">"))})

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
            @state = @states[:comment]
        else
            5.times { charStack.push(@stream.char) }
            # Put in explicit :EOF check
            if ((not charStack.include? :EOF) and
                charStack.join("").upcase == "DOCTYPE")
                @currentToken =\
                  {:type => :Doctype, :name => "", :data => true}
                @state = @states[:doctype]
            else
                @tokenQueue.push({:type => :ParseError, :data =>
                  _("Expected '--' or 'DOCTYPE'. Not found.")})
                @stream.queue += charStack
                @state = @states[:bogusComment]
            end
        end
        return true
    end

    def commentState
        data = @stream.char
        if data == "-"
            @state = @states[:commentDash]
        elsif data == :EOF
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Unexpected end of file in comment.")})
            @tokenQueue.push(@currentToken)
            @state = @states[:data]
        else
            @currentToken[:data] += data + @stream.charsUntil("-")
        end
        return true
    end

    def commentDashState
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
              @stream.charsUntil("-")
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
            @stream.queue.push(data)
            @state = @states[:beforeDoctypeName]
        end
        return true
    end

    def beforeDoctypeNameState
        data = @stream.char
        if SPACE_CHARACTERS.include? data
        elsif ASCII_LOWERCASE.include? data
            @currentToken[:name] = data.upcase
            @state = @states[:doctypeName]
        elsif data == ">"
            # Character needs to be consumed per the specification so don't
            # invoke emitCurrentTokenWithParseError with :data as argument.
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Unexpected > character. Expected DOCTYPE name.")})
            @tokenQueue.push(@currentToken)
            @state = @states[:data]
        elsif data == :EOF
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Unexpected end of file. Expected DOCTYPE name.")})
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
        needsDoctypeCheck = false
        if SPACE_CHARACTERS.include? data
            @state = @states[:afterDoctypeName]
            needsDoctypeCheck = true
        elsif data == ">"
            @tokenQueue.push(@currentToken)
            @state = @states[:data]
        elsif data == :EOF
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Unexpected end of file in DOCTYPE name.")})
            @tokenQueue.push(@currentToken)
            @state = @states[:data]
        else
            # We can't just uppercase everything that arrives here. For
            # instance, non-ASCII characters.
            if ASCII_LOWERCASE.include? data
                data = data.upcase
            end
            @currentToken[:name] += data
            needsDoctypeCheck = true
        end

        # After some iterations through this state it should eventually say
        # "HTML". Otherwise there's an error.
        if needsDoctypeCheck and @currentToken[:name] == "HTML"
            @currentToken[:data] = false
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
            # XXX EMIT
            @stream.queue.push(data)
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Unexpected end of file in DOCTYPE.")})
            @tokenQueue.push(@currentToken)
            @state = @states[:data]
        else
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Expected space or '>'. Got '" + data + "'")})
            @currentToken[:data] = true
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
            @stream.queue.push(data)
            @tokenQueue.push({:type => :ParseError, :data =>
              _("Unexpected end of file in bogus doctype.")})
            @tokenQueue.push(@currentToken)
            @state = @states[:data]
        end
        return true
    end

    def _(string); string; end
end

end
