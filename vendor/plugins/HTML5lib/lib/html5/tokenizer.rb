require 'html5/constants'
require 'html5/inputstream'

module HTML5

  # This class takes care of tokenizing HTML.
  #
  # * @current_token
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
    attr_accessor :content_model_flag, :current_token
    attr_reader :stream

    # XXX need to fix documentation

    def initialize(stream, options = {})
      @stream = HTMLInputStream.new(stream, options)

      # Setup the initial tokenizer state
      @content_model_flag = :PCDATA
      @state              = :data_state
      @escapeFlag         = false
      @lastFourChars      = []

      # The current token being created
      @current_token = nil

      # Tokens to be processed.
      @token_queue             = []
      @lowercase_element_name = options[:lowercase_element_name] != false
      @lowercase_attr_name    = options[:lowercase_attr_name]    != false
    end

    # This is where the magic happens.
    #
    # We do our usually processing through the states and when we have a token
    # to return we yield the token which pauses processing until the next token
    # is requested.
    def each
      @token_queue = []
      # Start processing. When EOF is reached @state will return false
      # instead of true and the loop will terminate.
      while send @state
        yield :type => :ParseError, :data => @stream.errors.shift until @stream.errors.empty?
        yield @token_queue.shift until @token_queue.empty?
      end
    end

    # Below are various helper functions the tokenizer states use worked out.
  
    # If the next character is a '>', convert the current_token into
    # an EmptyTag

    def process_solidus_in_tag

      # We need to consume another character to make sure it's a ">"
      data = @stream.char

      if @current_token[:type] == :StartTag and data == ">"
        @current_token[:type] = :EmptyTag
      else
        @token_queue << {:type => :ParseError, :data => _("Solidus (/) incorrectly placed in tag.")}
      end

      # The character we just consumed need to be put back on the stack so it
      # doesn't get lost...
      @stream.unget(data)
    end

    # This function returns either U+FFFD or the character based on the
    # decimal or hexadecimal representation. It also discards ";" if present.
    # If not present @token_queue << {:type => :ParseError}" is invoked.

    def consume_number_entity(isHex)

      # XXX More need to be done here. For instance, #13 should prolly be
      # converted to #10 so we don't get \r (#13 is \r right?) in the DOM and
      # such. Thoughts on this appreciated.
      allowed = DIGITS
      radix = 10
      if isHex
        allowed = HEX_DIGITS
        radix = 16
      end

      char_stack = []

      # Consume all the characters that are in range while making sure we
      # don't hit an EOF.
      c = @stream.char
      while allowed.include?(c) and c != :EOF
        char_stack.push(c)
        c = @stream.char
      end

      # Convert the set of characters consumed to an int.
      charAsInt = char_stack.join('').to_i(radix)

      if charAsInt == 13
        @token_queue << {:type => :ParseError, :data => _("Incorrect CR newline entity. Replaced with LF.")}
        charAsInt = 10
      elsif (128..159).include? charAsInt
        # If the integer is between 127 and 160 (so 128 and bigger and 159
        # and smaller) we need to do the "windows trick".
        @token_queue << {:type => :ParseError, :data => _("Entity used with illegal number (windows-1252 reference).")}

        charAsInt = ENTITIES_WINDOWS1252[charAsInt - 128]
      end

      if 0 < charAsInt and charAsInt <= 1114111 and not (55296 <= charAsInt and charAsInt <= 57343)
        char = [charAsInt].pack('U')
      else
        char = [0xFFFD].pack('U')
        @token_queue << {:type => :ParseError, :data => _("Numeric entity represents an illegal codepoint.")}
      end

      # Discard the ; if present. Otherwise, put it back on the queue and
      # invoke parse_error on parser.
      if c != ";"
        @token_queue << {:type => :ParseError, :data => _("Numeric entity didn't end with ';'.")}
        @stream.unget(c)
      end

      return char
    end

    def consume_entity(from_attribute=false)
      char = nil
      char_stack = [@stream.char]
      if SPACE_CHARACTERS.include?(char_stack[0]) or [:EOF, '<', '&'].include?(char_stack[0])
        @stream.unget(char_stack)
      elsif char_stack[0] == '#'
        # We might have a number entity here.
        char_stack += [@stream.char, @stream.char]
        if char_stack[0 .. 1].include? :EOF
          # If we reach the end of the file put everything up to :EOF
          # back in the queue
          char_stack = char_stack[0...char_stack.index(:EOF)]
          @stream.unget(char_stack)
          @token_queue << {:type => :ParseError, :data => _("Numeric entity expected. Got end of file instead.")}
        else
          if char_stack[1].downcase == "x" and HEX_DIGITS.include? char_stack[2]
            # Hexadecimal entity detected.
            @stream.unget(char_stack[2])
            char = consume_number_entity(true)
          elsif DIGITS.include? char_stack[1]
            # Decimal entity detected.
            @stream.unget(char_stack[1..-1])
            char = consume_number_entity(false)
          else
            # No number entity detected.
            @stream.unget(char_stack)
            @token_queue << {:type => :ParseError, :data => _("Numeric entity expected but none found.")}
          end
        end
      else
        # At this point in the process might have named entity. Entities
        # are stored in the global variable "entities".
        #
        # Consume characters and compare to these to a substring of the
        # entity names in the list until the substring no longer matches.
        filteredEntityList = ENTITIES.keys
        filteredEntityList.reject! {|e| e[0].chr != char_stack[0]}
        entityName = nil

        # Try to find the longest entity the string will match to take care
        # of &noti for instance.
        while char_stack.last != :EOF
          name = char_stack.join('')
          if filteredEntityList.any? {|e| e[0...name.length] == name}
            filteredEntityList.reject! {|e| e[0...name.length] != name}
            char_stack.push(@stream.char)
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
            @token_queue << {:type => :ParseError, :data => _("Named entity didn't end with ';'.")}
          end

          if char_stack[-1] != ";" and from_attribute and
             (ASCII_LETTERS.include?(char_stack[entityName.length]) or
              DIGITS.include?(char_stack[entityName.length]))
            @stream.unget(char_stack)
            char = '&'
          else
            @stream.unget(char_stack[entityName.length..-1])
          end
        else
          @token_queue << {:type => :ParseError, :data => _("Named entity expected. Got none.")}
          @stream.unget(char_stack)
        end
      end
      return char
    end

    # This method replaces the need for "entityInAttributeValueState".
    def process_entity_in_attribute
      entity = consume_entity(true)
      if entity
        @current_token[:data][-1][1] += entity
      else
        @current_token[:data][-1][1] += "&"
      end
    end

    # This method is a generic handler for emitting the tags. It also sets
    # the state to "data" because that's what's needed after a token has been
    # emitted.
    def emit_current_token
      # Add token to the queue to be yielded
      token = @current_token
      if [:StartTag, :EndTag, :EmptyTag].include?(token[:type])
        if @lowercase_element_name
          token[:name] = token[:name].downcase
        end
        @token_queue << token
        @state = :data_state
      end
      
    end

    # Below are the various tokenizer states worked out.

    # XXX AT Perhaps we should have Hixie run some evaluation on billions of
    # documents to figure out what the order of the various if and elsif
    # statements should be.
    def data_state
      data = @stream.char

      if @content_model_flag == :CDATA or @content_model_flag == :RCDATA
        @lastFourChars << data
        @lastFourChars.shift if @lastFourChars.length > 4
      end

      if data == "&" and [:PCDATA,:RCDATA].include?(@content_model_flag) and !@escapeFlag
          @state = :entity_data_state
      elsif data == "-" && [:CDATA, :RCDATA].include?(@content_model_flag) && !@escapeFlag && @lastFourChars.join('') == "<!--"
          @escapeFlag = true
          @token_queue << {:type => :Characters, :data => data}
      elsif data == "<" and !@escapeFlag and
        [:PCDATA,:CDATA,:RCDATA].include?(@content_model_flag)
          @state = :tag_open_state
      elsif data == ">" and @escapeFlag and 
        [:CDATA,:RCDATA].include?(@content_model_flag) and
        @lastFourChars[1..-1].join('') == "-->"
          @escapeFlag = false
          @token_queue << {:type => :Characters, :data => data}

      elsif data == :EOF
        # Tokenization ends.
        return false

      elsif SPACE_CHARACTERS.include? data
        # Directly after emitting a token you switch back to the "data
        # state". At that point SPACE_CHARACTERS are important so they are
        # emitted separately.
        # XXX need to check if we don't need a special "spaces" flag on
        # characters.
        @token_queue << {:type => :SpaceCharacters, :data => data + @stream.chars_until(SPACE_CHARACTERS, true)}
      else
        @token_queue << {:type => :Characters, :data => data + @stream.chars_until(%w[& < > -])}
      end
      return true
    end

    def entity_data_state
      entity = consume_entity
      if entity
        @token_queue << {:type => :Characters, :data => entity}
      else
        @token_queue << {:type => :Characters, :data => "&"}
      end
      @state = :data_state
      return true
    end

    def tag_open_state
      data = @stream.char
      if @content_model_flag == :PCDATA
        if data == "!"
          @state = :markup_declaration_open_state
        elsif data == "/"
          @state = :close_tag_open_state
        elsif data != :EOF and ASCII_LETTERS.include? data
          @current_token = {:type => :StartTag, :name => data, :data => []}
          @state = :tag_name_state
        elsif data == ">"
          # XXX In theory it could be something besides a tag name. But
          # do we really care?
          @token_queue << {:type => :ParseError, :data =>       _("Expected tag name. Got '>' instead.")}
          @token_queue << {:type => :Characters, :data => "<>"}
          @state = :data_state
        elsif data == "?"
          # XXX In theory it could be something besides a tag name. But
          # do we really care?
          @token_queue.push({:type => :ParseError, :data => _("Expected tag name. Got '?' instead (HTML doesn't " +
            "support processing instructions).")})
          @stream.unget(data)
          @state = :bogus_comment_state
        else
          # XXX
          @token_queue << {:type => :ParseError, :data => _("Expected tag name. Got something else instead")}
          @token_queue << {:type => :Characters, :data => "<"}
          @stream.unget(data)
          @state = :data_state
        end
      else
        # We know the content model flag is set to either RCDATA or CDATA
        # now because this state can never be entered with the PLAINTEXT
        # flag.
        if data == "/"
          @state = :close_tag_open_state
        else
          @token_queue << {:type => :Characters, :data => "<"}
          @stream.unget(data)
          @state = :data_state
        end
      end
      return true
    end

    def close_tag_open_state
      if (@content_model_flag == :RCDATA or @content_model_flag == :CDATA)
        if @current_token
          char_stack = []

          # So far we know that "</" has been consumed. We now need to know
          # whether the next few characters match the name of last emitted
          # start tag which also happens to be the current_token. We also need
          # to have the character directly after the characters that could
          # match the start tag name.
          (@current_token[:name].length + 1).times do
            char_stack.push(@stream.char)
            # Make sure we don't get hit by :EOF
            break if char_stack[-1] == :EOF
          end

          # Since this is just for checking. We put the characters back on
          # the stack.
          @stream.unget(char_stack)
        end

        if @current_token and
          @current_token[:name].downcase == 
          char_stack[0...-1].join('').downcase and
          (SPACE_CHARACTERS + [">", "/", "<", :EOF]).include? char_stack[-1]
          # Because the characters are correct we can safely switch to
          # PCDATA mode now. This also means we don't have to do it when
          # emitting the end tag token.
          @content_model_flag = :PCDATA
        else
          @token_queue << {:type => :Characters, :data => "</"}
          @state = :data_state

          # Need to return here since we don't want the rest of the
          # method to be walked through.
          return true
        end
      end

      data = @stream.char
      if data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Expected closing tag. Unexpected end of file.")}
        @token_queue << {:type => :Characters, :data => "</"}
        @state = :data_state
      elsif ASCII_LETTERS.include? data
        @current_token = {:type => :EndTag, :name => data, :data => []}
        @state = :tag_name_state
      elsif data == ">"
        @token_queue << {:type => :ParseError, :data => _("Expected closing tag. Got '>' instead. Ignoring '</>'.")}
        @state = :data_state
      else
        # XXX data can be _'_...
        @token_queue << {:type => :ParseError, :data => _("Expected closing tag. Unexpected character '#{data}' found.")}
        @stream.unget(data)
        @state = :bogus_comment_state
      end

      return true
    end

    def tag_name_state
      data = @stream.char
      if SPACE_CHARACTERS.include? data
        @state = :before_attribute_name_state
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in the tag name.")}
        emit_current_token
      elsif ASCII_LETTERS.include? data
        @current_token[:name] += data + @stream.chars_until(ASCII_LETTERS, true)
      elsif data == ">"
        emit_current_token
      elsif data == "/"
        process_solidus_in_tag
        @state = :before_attribute_name_state
      else
        @current_token[:name] += data
      end
      return true
    end

    def before_attribute_name_state
      data = @stream.char
      if SPACE_CHARACTERS.include? data
        @stream.chars_until(SPACE_CHARACTERS, true)
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file. Expected attribute name instead.")}
        emit_current_token
      elsif ASCII_LETTERS.include? data
        @current_token[:data].push([data, ""])
        @state = :attribute_name_state
      elsif data == ">"
        emit_current_token
      elsif data == "/"
        process_solidus_in_tag
      else
        @current_token[:data].push([data, ""])
        @state = :attribute_name_state
      end
      return true
    end

    def attribute_name_state
      data = @stream.char
      leavingThisState = true
      emitToken = false
      if data == "="
        @state = :before_attribute_value_state
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in attribute name.")}
        @state = :data_state
        emitToken = true
      elsif ASCII_LETTERS.include? data
        @current_token[:data][-1][0] += data + @stream.chars_until(ASCII_LETTERS, true)
        leavingThisState = false
      elsif data == ">"
        # XXX If we emit here the attributes are converted to a dict
        # without being checked and when the code below runs we error
        # because data is a dict not a list
        emitToken = true
      elsif SPACE_CHARACTERS.include? data
        @state = :after_attribute_name_state
      elsif data == "/"
        process_solidus_in_tag
        @state = :before_attribute_name_state
      else
        @current_token[:data][-1][0] += data
        leavingThisState = false
      end

      if leavingThisState
        # Attributes are not dropped at this stage. That happens when the
        # start tag token is emitted so values can still be safely appended
        # to attributes, but we do want to report the parse error in time.
        if @lowercase_attr_name
            @current_token[:data][-1][0] = @current_token[:data].last.first.downcase
        end
        @current_token[:data][0...-1].each {|name,value|
          if @current_token[:data].last.first == name
            @token_queue << {:type => :ParseError, :data =>_("Dropped duplicate attribute on tag.")}
            break # don't report an error more than once
          end
        }
        # XXX Fix for above XXX
        emit_current_token if emitToken
      end
      return true
    end

    def after_attribute_name_state
      data = @stream.char
      if SPACE_CHARACTERS.include? data
        @stream.chars_until(SPACE_CHARACTERS, true)
      elsif data == "="
        @state = :before_attribute_value_state
      elsif data == ">"
        emit_current_token
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file. Expected = or end of tag.")}
        emit_current_token
      elsif ASCII_LETTERS.include? data
        @current_token[:data].push([data, ""])
        @state = :attribute_name_state
      elsif data == "/"
        process_solidus_in_tag
        @state = :before_attribute_name_state
      else
        @current_token[:data].push([data, ""])
        @state = :attribute_name_state
      end
      return true
    end

    def before_attribute_value_state
      data = @stream.char
      if SPACE_CHARACTERS.include? data
        @stream.chars_until(SPACE_CHARACTERS, true)
      elsif data == "\""
        @state = :attribute_value_double_quoted_state
      elsif data == "&"
        @state = :attribute_value_unquoted_state
        @stream.unget(data);
      elsif data == "'"
        @state = :attribute_value_single_quoted_state
      elsif data == ">"
        emit_current_token
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file. Expected attribute value.")}
        emit_current_token
      else
        @current_token[:data][-1][1] += data
        @state = :attribute_value_unquoted_state
      end
      return true
    end

    def attribute_value_double_quoted_state
      data = @stream.char
      if data == "\""
        @state = :before_attribute_name_state
      elsif data == "&"
        process_entity_in_attribute
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in attribute value (\").")}
        emit_current_token
      else
        @current_token[:data][-1][1] += data + @stream.chars_until(["\"", "&"])
      end
      return true
    end

    def attribute_value_single_quoted_state
      data = @stream.char
      if data == "'"
        @state = :before_attribute_name_state
      elsif data == "&"
        process_entity_in_attribute
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in attribute value (').")}
        emit_current_token
      else
        @current_token[:data][-1][1] += data +\
          @stream.chars_until(["'", "&"])
      end
      return true
    end

    def attribute_value_unquoted_state
      data = @stream.char
      if SPACE_CHARACTERS.include? data
        @state = :before_attribute_name_state
      elsif data == "&"
        process_entity_in_attribute
      elsif data == ">"
        emit_current_token
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in attribute value.")}
        emit_current_token
      else
        @current_token[:data][-1][1] += data +  @stream.chars_until(["&", ">","<"] + SPACE_CHARACTERS)
      end
      return true
    end

    def bogus_comment_state
      # Make a new comment token and give it as value all the characters
      # until the first > or :EOF (chars_until checks for :EOF automatically)
      # and emit it.
      @token_queue << {:type => :Comment, :data => @stream.chars_until((">"))}

      # Eat the character directly after the bogus comment which is either a
      # ">" or an :EOF.
      @stream.char
      @state = :data_state
      return true
    end

    def markup_declaration_open_state
      char_stack = [@stream.char, @stream.char]
      if char_stack == ["-", "-"]
        @current_token = {:type => :Comment, :data => ""}
        @state = :comment_start_state
      else
        5.times { char_stack.push(@stream.char) }
        # Put in explicit :EOF check
        if !char_stack.include?(:EOF) && char_stack.join("").upcase == "DOCTYPE"
          @current_token = {:type => :Doctype, :name => "", :publicId => nil, :systemId => nil, :correct => true}
          @state = :doctype_state
        else
          @token_queue << {:type => :ParseError, :data => _("Expected '--' or 'DOCTYPE'. Not found.")}
          @stream.unget(char_stack)
          @state = :bogus_comment_state
        end
      end
      return true
    end

    def comment_start_state
        data = @stream.char
        if data == "-"
            @state = :comment_start_dash_state
        elsif data == ">"
            @token_queue << {:type => :ParseError, :data => _("Incorrect comment.")}
            @token_queue << @current_token
            @state = :data_state
        elsif data == :EOF
            @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in comment.")}
            @token_queue << @current_token
            @state = :data_state
        else
            @current_token[:data] += data + @stream.chars_until("-")
            @state = :comment_state
        end
        return true
    end
    
    def comment_start_dash_state
        data = @stream.char
        if data == "-"
            @state = :comment_end_state
        elsif data == ">"
            @token_queue << {:type => :ParseError, :data => _("Incorrect comment.")}
            @token_queue << @current_token
            @state = :data_state
        elsif data == :EOF
            @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in comment.")}
            @token_queue << @current_token
            @state = :data_state
        else
            @current_token[:data] += '-' + data + @stream.chars_until("-")
            @state = :comment_state
        end
        return true
    end

    def comment_state
      data = @stream.char
      if data == "-"
        @state = :comment_end_dash_state
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in comment.")}
        @token_queue << @current_token
        @state = :data_state
      else
        @current_token[:data] += data + @stream.chars_until("-")
      end
      return true
    end

    def comment_end_dash_state
      data = @stream.char
      if data == "-"
        @state = :comment_end_state
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in comment (-)")}
        @token_queue << @current_token
        @state = :data_state
      else
        @current_token[:data] += "-" + data +\
          @stream.chars_until("-")
        # Consume the next character which is either a "-" or an :EOF as
        # well so if there's a "-" directly after the "-" we go nicely to
        # the "comment end state" without emitting a ParseError there.
        @stream.char
      end
      return true
    end

    def comment_end_state
      data = @stream.char
      if data == ">"
        @token_queue << @current_token
        @state = :data_state
      elsif data == "-"
        @token_queue << {:type => :ParseError, :data => _("Unexpected '-' after '--' found in comment.")}
        @current_token[:data] += data
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in comment (--).")}
        @token_queue << @current_token
        @state = :data_state
      else
        # XXX
        @token_queue << {:type => :ParseError, :data => _("Unexpected character in comment found.")}
        @current_token[:data] += "--" + data
        @state = :comment_state
      end
      return true
    end

    def doctype_state
      data = @stream.char
      if SPACE_CHARACTERS.include? data
        @state = :before_doctype_name_state
      else
        @token_queue << {:type => :ParseError, :data => _("No space after literal string 'DOCTYPE'.")}
        @stream.unget(data)
        @state = :before_doctype_name_state
      end
      return true
    end

    def before_doctype_name_state
      data = @stream.char
      if SPACE_CHARACTERS.include? data
      elsif data == ">"
        @token_queue << {:type => :ParseError, :data => _("Unexpected > character. Expected DOCTYPE name.")}
        @current_token[:correct] = false
        @token_queue << @current_token
        @state = :data_state
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data =>          _("Unexpected end of file. Expected DOCTYPE name.")}
        @current_token[:correct] = false
        @token_queue << @current_token
        @state = :data_state
      else
        @current_token[:name] = data
        @state = :doctype_name_state
      end
      return true
    end

    def doctype_name_state
      data = @stream.char
      if SPACE_CHARACTERS.include? data
        @state = :after_doctype_name_state
      elsif data == ">"
        @token_queue << @current_token
        @state = :data_state
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in DOCTYPE name.")}
        @current_token[:correct] = false
        @token_queue << @current_token
        @state = :data_state
      else
        @current_token[:name] += data
      end

      return true
    end

    def after_doctype_name_state
      data = @stream.char
      if SPACE_CHARACTERS.include? data
      elsif data == ">"
        @token_queue << @current_token
        @state = :data_state
      elsif data == :EOF
        @current_token[:correct] = false
        @stream.unget(data)
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in DOCTYPE.")}
        @token_queue << @current_token
        @state = :data_state
      else
        char_stack = [data]  
        5.times { char_stack << stream.char }
        token = char_stack.join('').tr(ASCII_UPPERCASE,ASCII_LOWERCASE)
        if token == "public" and !char_stack.include?(:EOF)
          @state = :before_doctype_public_identifier_state
        elsif token == "system" and !char_stack.include?(:EOF)
          @state = :before_doctype_system_identifier_state
        else
          @stream.unget(char_stack)
          @token_queue << {:type => :ParseError, :data => _("Expected 'public' or 'system'. Got '#{token}'")}
          @state = :bogus_doctype_state
        end
      end
      return true
    end
    
    def before_doctype_public_identifier_state
      data = @stream.char

      if SPACE_CHARACTERS.include?(data)
      elsif data == "\""
        @current_token[:publicId] = ""
        @state = :doctype_public_identifier_double_quoted_state
      elsif data == "'"
        @current_token[:publicId] = ""
        @state = :doctype_public_identifier_single_quoted_state
      elsif data == ">"
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of DOCTYPE.")}
        @current_token[:correct] = false
        @token_queue << @current_token
        @state = :data_state
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in DOCTYPE.")}
        @current_token[:correct] = false
        @token_queue << @current_token
        @state = :data_state
      else
        @token_queue << {:type => :ParseError, :data => _("Unexpected character in DOCTYPE.")}
        @state = :bogus_doctype_state
      end

      return true
    end
 
    def doctype_public_identifier_double_quoted_state
      data = @stream.char
      if data == "\""
        @state = :after_doctype_public_identifier_state
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in DOCTYPE.")}
        @current_token[:correct] = false
        @token_queue << @current_token
        @state = :data_state
      else
        @current_token[:publicId] += data
      end
      return true
    end

    def doctype_public_identifier_single_quoted_state
      data = @stream.char
      if data == "'"
        @state = :after_doctype_public_identifier_state
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in DOCTYPE.")}
        @current_token[:correct] = false
        @token_queue << @current_token
        @state = :data_state
      else
        @current_token[:publicId] += data
      end
      return true
    end

    def after_doctype_public_identifier_state
      data = @stream.char
      if SPACE_CHARACTERS.include?(data)
      elsif data == "\""
        @current_token[:systemId] = ""
        @state = :doctype_system_identifier_double_quoted_state
      elsif data == "'"
        @current_token[:systemId] = ""
        @state = :doctype_system_identifier_single_quoted_state
      elsif data == ">"
        @token_queue << @current_token
        @state = :data_state
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in DOCTYPE.")}
        @current_token[:correct] = false
        @token_queue << @current_token
        @state = :data_state
      else
        @token_queue << {:type => :ParseError, :data => _("Unexpected character in DOCTYPE.")}
        @state = :bogus_doctype_state
      end
      return true
    end
    
    def before_doctype_system_identifier_state
      data = @stream.char
      if SPACE_CHARACTERS.include?(data)
      elsif data == "\""
        @current_token[:systemId] = ""
        @state = :doctype_system_identifier_double_quoted_state
      elsif data == "'"
        @current_token[:systemId] = ""
        @state = :doctype_system_identifier_single_quoted_state
      elsif data == ">"
        @token_queue << {:type => :ParseError, :data => _("Unexpected character in DOCTYPE.")}
        @current_token[:correct] = false
        @token_queue << @current_token
        @state = :data_state
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in DOCTYPE.")}
        @current_token[:correct] = false
        @token_queue << @current_token
        @state = :data_state
      else
        @token_queue << {:type => :ParseError, :data => _("Unexpected character in DOCTYPE.")}
        @state = :bogus_doctype_state
      end
      return true
    end

    def doctype_system_identifier_double_quoted_state
      data = @stream.char
      if data == "\""
        @state = :after_doctype_system_identifier_state
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in DOCTYPE.")}
        @current_token[:correct] = false
        @token_queue << @current_token
        @state = :data_state
      else
        @current_token[:systemId] += data
      end
      return true
    end

    def doctype_system_identifier_single_quoted_state
      data = @stream.char
      if data == "'"
        @state = :after_doctype_system_identifier_state
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in DOCTYPE.")}
        @current_token[:correct] = false
        @token_queue << @current_token
        @state = :data_state
      else
        @current_token[:systemId] += data
      end
      return true
    end

    def after_doctype_system_identifier_state
      data = @stream.char
      if SPACE_CHARACTERS.include?(data)
      elsif data == ">"
        @token_queue << @current_token
        @state = :data_state
      elsif data == :EOF
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in DOCTYPE.")}
        @current_token[:correct] = false
        @token_queue << @current_token
        @state = :data_state
      else
        @token_queue << {:type => :ParseError, :data => _("Unexpected character in DOCTYPE.")}
        @state = :bogus_doctype_state
      end
      return true
    end

    def bogus_doctype_state
      data = @stream.char
      @current_token[:correct] = false
      if data == ">"
        @token_queue << @current_token
        @state = :data_state
      elsif data == :EOF
        # XXX EMIT
        @stream.unget(data)
        @token_queue << {:type => :ParseError, :data => _("Unexpected end of file in bogus doctype.")}
        @current_token[:correct] = false
        @token_queue << @current_token
        @state = :data_state
      end
      return true
    end

    def _(string); string; end
  end

end
