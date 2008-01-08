require 'stringio'
require 'html5/constants'

module HTML5

  # Provides a unicode stream of characters to the HTMLTokenizer.

  # This class takes care of character encoding and removing or replacing
  # incorrect byte-sequences and also provides column and line tracking.

  class HTMLInputStream

    attr_accessor :queue, :char_encoding, :errors

    # Initialises the HTMLInputStream.
    # 
    # HTMLInputStream(source, [encoding]) -> Normalized stream from source
    # for use by the HTML5Lib.
    # 
    # source can be either a file-object, local filename or a string.
    # 
    # The optional encoding parameter must be a string that indicates
    # the encoding.  If specified, that encoding will be used,
    # regardless of any BOM or later declaration (such as in a meta
    # element)
    #  
    # parseMeta - Look for a <meta> element containing encoding information

    def initialize(source, options = {})
      @encoding   = nil
      @parse_meta = true
      @chardet    = true

      options.each {|name, value| instance_variable_set("@#{name}", value) }

      # partial Ruby 1.9 support
      if @encoding and source.respond_to? :force_encoding
        source.force_encoding(@encoding) rescue nil
      end

      # Raw Stream
      @raw_stream = open_stream(source)

      # Encoding Information
      #Number of bytes to use when looking for a meta element with
      #encoding information
      @NUM_BYTES_META = 512
      #Number of bytes to use when using detecting encoding using chardet
      @NUM_BYTES_CHARDET = 256
      #Number of bytes to use when reading content
      @NUM_BYTES_BUFFER = 1024

      #Encoding to use if no other information can be found
      @DEFAULT_ENCODING = 'windows-1252'

      #Detect encoding iff no explicit "transport level" encoding is supplied
      if @encoding.nil? or not HTML5.is_valid_encoding(@encoding)
        @char_encoding = detect_encoding
      else
        @char_encoding = @encoding
      end

      # Read bytes from stream decoding them into Unicode
      @buffer = @raw_stream.read(@NUM_BYTES_BUFFER) || ''
      if @char_encoding == 'windows-1252'
        @win1252 = true
      elsif @char_encoding != 'utf-8'
        require 'iconv'
        begin
          @buffer << @raw_stream.read unless @raw_stream.eof?
          @buffer = Iconv.iconv('utf-8', @char_encoding, @buffer).first
        rescue
          @win1252 = true
        end
      end

      @queue = []
      @errors = []

      # Reset position in the list to read from
      @tell = 0
      @line = @col = 0
      @line_lengths = []
    end

    # Produces a file object from source.
    #
    # source can be either a file object, local filename or a string.
    def open_stream(source)
      # Already an IO like object
      if source.respond_to?(:read)
        source
      else
        # Treat source as a string and wrap in StringIO
        StringIO.new(source)
      end
    end

    def detect_encoding

      #First look for a BOM
      #This will also read past the BOM if present
      encoding = detect_bom

      #If there is no BOM need to look for meta elements with encoding 
      #information
      if encoding.nil? and @parse_meta
        encoding = detect_encoding_meta
      end

      #Guess with chardet, if avaliable
      if encoding.nil? and @chardet
        begin
          require 'rubygems'
          require 'UniversalDetector' # gem install chardet
          buffers = []
          detector = UniversalDetector::Detector.instance
          detector.reset
          until @raw_stream.eof?
            buffer = @raw_stream.read(@NUM_BYTES_CHARDET)
            break if !buffer or buffer.empty?
            buffers << buffer
            detector.feed(buffer)
            break if detector.instance_eval {@done}
            detector.instance_eval {
              @_mLastChar = @_mLastChar.chr if Fixnum === @_mLastChar
            }
          end
          detector.close
          encoding = detector.result['encoding']
          seek(buffers*'', 0)
        rescue LoadError
        end
      end

      # If all else fails use the default encoding
      if encoding.nil?
        encoding = @DEFAULT_ENCODING
      end
    
      #Substitute for equivalent encoding
      if 'iso-8859-1' == encoding.downcase
        encoding = 'windows-1252'
      end

      encoding
    end

    # Attempts to detect at BOM at the start of the stream. If
    # an encoding can be determined from the BOM return the name of the
    # encoding otherwise return nil
    def detect_bom
      bom_dict = {
        "\xef\xbb\xbf"     => 'utf-8',
        "\xff\xfe"         => 'utf-16le',
        "\xfe\xff"         => 'utf-16be',
        "\xff\xfe\x00\x00" => 'utf-32le',
        "\x00\x00\xfe\xff" => 'utf-32be'
      }

      # Go to beginning of file and read in 4 bytes
      string = @raw_stream.read(4)
      return nil unless string

      # Try detecting the BOM using bytes from the string
      encoding = bom_dict[string[0...3]]      # UTF-8
      seek = 3
      unless encoding
        # Need to detect UTF-32 before UTF-16
        encoding = bom_dict[string]       # UTF-32
        seek = 4
        unless encoding
          encoding = bom_dict[string[0...2]]  # UTF-16
          seek = 2
        end
      end

      # Set the read position past the BOM if one was found, otherwise
      # set it to the start of the stream
      seek(string, encoding ? seek : 0)

      return encoding
    end

    def seek(buffer, n)
      if @raw_stream.respond_to?(:unget)
        @raw_stream.unget(buffer[n..-1])
        return
      end

      if @raw_stream.respond_to?(:seek)
        begin
          @raw_stream.seek(n)
          return
        rescue Errno::ESPIPE
        end
      end

      #TODO: huh?
      require 'delegate'
      @raw_stream = SimpleDelegator.new(@raw_stream)

      class << @raw_stream
        def read(chars=-1)
          if chars == -1 or chars > @data.length
            result = @data
            @data = ''
            return result if __getobj__.eof?
            return result + __getobj__.read if chars == -1
            return result + __getobj__.read(chars-result.length)
          elsif @data.empty?
            return __getobj__.read(chars)
          else
            result = @data[1...chars]
            @data = @data[chars..-1]
            return result
          end
        end

        def unget(data)
          if !@data or @data.empty?
            @data = data
          else
            @data += data
          end
        end
      end

      @raw_stream.unget(buffer[n .. -1])
    end

    # Report the encoding declared by the meta element
    def detect_encoding_meta
      buffer = @raw_stream.read(@NUM_BYTES_META)
      parser = EncodingParser.new(buffer)
      seek(buffer, 0)
      return parser.get_encoding
    end

    # Returns (line, col) of the current position in the stream.
    def position
      line, col = @line, @col
      if @queue and @queue.last != :EOF
        @queue.reverse.each do |c|
          if c == "\n"
            line -= 1
            raise RuntimeError.new("col=#{col}") unless col == 0
            col = @line_lengths[line]
          else
            col -= 1
          end 
        end
      end
      return [line + 1, col]
    end

    # Read one character from the stream or queue if available. Return
    # EOF when EOF is reached.
    def char
      unless @queue.empty?
        return @queue.shift
      else
        if @tell + 3 > @buffer.length && !@raw_stream.eof?
          # read next block
          @buffer = @buffer[@tell..-1] + @raw_stream.read(@NUM_BYTES_BUFFER)
          @tell = 0
        end

        c = @buffer[@tell]
        @tell += 1

        case c

        when String
          # partial Ruby 1.9 support
          case c
          when "\0"
            @errors.push("null-character")
            c = "\uFFFD" # null characters are invalid
          when "\r"
            @tell += 1 if @buffer[@tell] == "\n"
            c = "\n"
          when "\x80" .. "\x9F"
            c = ''.force_encoding('UTF-8') << ENTITIES_WINDOWS1252[c.ord-0x80]
          end

          if c == "\x0D"
            # normalize newlines
            @tell += 1 if @buffer[@tell] == 0x0A
            c = 0x0A
          end

          # update position in stream
          if c == "\x0a"
            @line_lengths << @col
            @line += 1
            @col = 0
          else
            @col += 1
          end

          # binary utf-8
          c.ord > 126 ? [c.ord].pack('U') : c

        when 0x01..0x7F
          if c == 0x0D
            # normalize newlines
            @tell += 1 if @buffer[@tell] == 0x0A
            c = 0x0A
          end

          # update position in stream
          if c == 0x0a
            @line_lengths << @col
            @line += 1
            @col = 0
          else
            @col += 1
          end

          c.chr

        when 0x80..0xBF
          if !@win1252
            [0xFFFD].pack('U') # invalid utf-8
          elsif c <= 0x9f
            [ENTITIES_WINDOWS1252[c-0x80]].pack('U')
          else
            "\xC2" + c.chr # convert to utf-8
          end

        when 0xC0..0xFF
          if instance_variable_defined?("@win1252") && @win1252
            "\xC3" + (c - 64).chr # convert to utf-8
          # from http://www.w3.org/International/questions/qa-forms-utf-8.en.php
          elsif @buffer[@tell - 1..@tell + 3] =~ /^
                ( [\xC2-\xDF][\x80-\xBF]             # non-overlong 2-byte
                |  \xE0[\xA0-\xBF][\x80-\xBF]        # excluding overlongs
                | [\xE1-\xEC\xEE\xEF][\x80-\xBF]{2}  # straight 3-byte
                |  \xED[\x80-\x9F][\x80-\xBF]        # excluding surrogates
                |  \xF0[\x90-\xBF][\x80-\xBF]{2}     # planes 1-3
                | [\xF1-\xF3][\x80-\xBF]{3}          # planes 4-15
                |  \xF4[\x80-\x8F][\x80-\xBF]{2}     # plane 16
                )/x
            @tell += $1.length - 1
            $1
          else
            [0xFFFD].pack('U') # invalid utf-8
          end

        when 0x00
          @errors.push("null-character")
          [0xFFFD].pack('U') # null characters are invalid

        else
          :EOF
        end
      end
    end

    # Returns a string of characters from the stream up to but not
    # including any character in characters or EOF. characters can be
    # any container that supports the in method being called on it.
    def chars_until(characters, opposite=false)
      char_stack = [char]

      while char_stack.last != :EOF
        break unless (characters.include?(char_stack.last)) == opposite
        char_stack.push(char)
      end

      # Put the character stopped on back to the front of the queue
      # from where it came.
      c = char_stack.pop
      @queue.insert(0, c) unless c == :EOF
      return char_stack.join('')
    end

    def unget(characters)
      return if characters == :EOF
      if characters.respond_to? :to_a
        @queue.unshift(*characters.to_a)
      else
        characters.reverse.each_char {|c| @queue.unshift(c)}
      end
    end
  end

  # String-like object with an assosiated position and various extra methods
  # If the position is ever greater than the string length then an exception is raised
  class EncodingBytes < String

    attr_accessor :position

    def initialize(value)
      super(value)
      @position = -1
    end
  
    def each
      while @position < length
        @position += 1
        yield self[@position]
      end
    rescue EOF
    end
  
    def current_byte
      raise EOF if @position >= length
      return self[@position].chr
    end
  
    # Skip past a list of characters
    def skip(chars=SPACE_CHARACTERS)
      while chars.include?(current_byte)
        @position += 1
      end
    end

    # Look for a sequence of bytes at the start of a string. If the bytes 
    # are found return true and advance the position to the byte after the 
    # match. Otherwise return false and leave the position alone
    def match_bytes(bytes, lower=false)
      data = self[position ... position+bytes.length]
      data.downcase! if lower
      rv = (data == bytes)
      @position += bytes.length if rv == true
      return rv
    end
  
    # Look for the next sequence of bytes matching a given sequence. If
    # a match is found advance the position to the last byte of the match
    def jump_to(bytes)
      new_position = self[position .. -1].index(bytes)
      if new_position
        @position += (new_position + bytes.length-1)
        return true
      else
        raise EOF
      end
    end
  
    # Move the pointer so it points to the next byte in a set of possible
    # bytes
    def find_next(byte_list)
      until byte_list.include?(current_byte)
        @position += 1
      end
    end
  end

  # Mini parser for detecting character encoding from meta elements
  class EncodingParser

    # string - the data to work on for encoding detection
    def initialize(data)
      @data = EncodingBytes.new(data.to_s)
      @encoding = nil
    end

    @@method_dispatch = [
      ['<!--', :handle_comment],
      ['<meta', :handle_meta],
      ['</', :handle_possible_end_tag],
      ['<!', :handle_other],
      ['<?', :handle_other],
      ['<', :handle_possible_start_tag]
    ]

    def get_encoding
      @data.each do |byte|
        keep_parsing = true
        @@method_dispatch.each do |(key, method)|
          if @data.match_bytes(key, lower = true)
            keep_parsing = send(method)
            break
          end
        end
        break unless keep_parsing
      end
      unless @encoding.nil?
        @encoding = @encoding.strip 
        if ["UTF-16", "UTF-16BE", "UTF-16LE", "UTF-32", "UTF-32BE", "UTF-32LE"].include?(@encoding.upcase)
          @encoding = 'utf-8'
        end
      end
      
      return @encoding
    end

    # Skip over comments
    def handle_comment
      return @data.jump_to('-->')
    end

    def handle_meta
      # if we have <meta not followed by a space so just keep going
      return true unless SPACE_CHARACTERS.include?(@data.current_byte)

      #We have a valid meta element we want to search for attributes
      while true
        #Try to find the next attribute after the current position
        attr = get_attribute

        return true if attr.nil?
        
        if attr[0] == 'charset'
          tentative_encoding = attr[1]
          if HTML5.is_valid_encoding(tentative_encoding)
            @encoding = tentative_encoding  
            return false
          end
        elsif attr[0] == 'content'
          content_parser = ContentAttrParser.new(EncodingBytes.new(attr[1]))
          tentative_encoding = content_parser.parse
          if HTML5.is_valid_encoding(tentative_encoding)
            @encoding = tentative_encoding
            return false
          end
        end
      end
    end

    def handle_possible_start_tag
      return handle_possible_tag(false)
    end

    def handle_possible_end_tag
      @data.position += 1
      return handle_possible_tag(true)
    end

    def handle_possible_tag(end_tag)
      unless ASCII_LETTERS.include?(@data.current_byte)
        #If the next byte is not an ascii letter either ignore this
        #fragment (possible start tag case) or treat it according to 
        #handleOther
        if end_tag
          @data.position -= 1
          handle_other
        end
        return true
      end
    
      @data.find_next(SPACE_CHARACTERS + ['<', '>'])

      if @data.current_byte == '<'
        #return to the first step in the overall "two step" algorithm
        #reprocessing the < byte
        @data.position -= 1  
      else
        #Read all attributes
        {} until get_attribute.nil?
      end
      return true
    end

    def handle_other
      return @data.jump_to('>')
    end

    # Return a name,value pair for the next attribute in the stream,
    # if one is found, or nil
    def get_attribute
      @data.skip(SPACE_CHARACTERS + ['/'])

      if @data.current_byte == '<'
        @data.position -= 1
        return nil
      elsif @data.current_byte == '>'
        return nil
      end

      attr_name = []
      attr_value = []
      space_found = false
      #Step 5 attribute name
      while true
        if @data.current_byte == '=' and attr_name
          break
        elsif SPACE_CHARACTERS.include?(@data.current_byte)
          space_found = true
          break
        elsif ['/', '<', '>'].include?(@data.current_byte)
          return [attr_name.join(''), '']
        elsif ASCII_UPPERCASE.include?(@data.current_byte)
          attr_name.push(@data.current_byte.downcase)
        else
          attr_name.push(@data.current_byte)
        end
        #Step 6
        @data.position += 1
      end
      #Step 7
      if space_found
        @data.skip
        #Step 8
        unless @data.current_byte == '='
          @data.position -= 1
          return [attr_name.join(''), '']
        end
      end
      #XXX need to advance position in both spaces and value case
      #Step 9
      @data.position += 1
      #Step 10
      @data.skip
      #Step 11
      if ["'", '"'].include?(@data.current_byte)
        #11.1
        quote_char = @data.current_byte
        while true
          @data.position+=1
          #11.3
          if @data.current_byte == quote_char
            @data.position += 1
            return [attr_name.join(''), attr_value.join('')]
          #11.4
          elsif ASCII_UPPERCASE.include?(@data.current_byte)
            attr_value.push(@data.current_byte.downcase)
          #11.5
          else
            attr_value.push(@data.current_byte)
          end
        end
      elsif ['>', '<'].include?(@data.current_byte)
        return [attr_name.join(''), '']
      elsif ASCII_UPPERCASE.include?(@data.current_byte)
        attr_value.push(@data.current_byte.downcase)
      else
        attr_value.push(@data.current_byte)
      end
      while true
        @data.position += 1
        if (SPACE_CHARACTERS + ['>', '<']).include?(@data.current_byte)
          return [attr_name.join(''), attr_value.join('')]
        elsif ASCII_UPPERCASE.include?(@data.current_byte)
          attr_value.push(@data.current_byte.downcase)
        else
          attr_value.push(@data.current_byte)
        end
      end
    end
  end

  class ContentAttrParser
    def initialize(data)
      @data = data
    end

    def parse
      begin
        #Skip to the first ";"
        @data.position = 0
        @data.jump_to(';')
        @data.position += 1
        @data.skip
        #Check if the attr name is charset 
        #otherwise return
        @data.jump_to('charset')
        @data.position += 1
        @data.skip
        unless @data.current_byte == '='
          #If there is no = sign keep looking for attrs
          return nil
        end
        @data.position += 1
        @data.skip
        #Look for an encoding between matching quote marks
        if ['"', "'"].include?(@data.current_byte)
          quote_mark = @data.current_byte
          @data.position += 1
          old_position = @data.position
          @data.jump_to(quote_mark)
          return @data[old_position ... @data.position]
        else
          #Unquoted value
          old_position = @data.position
          begin
            @data.find_next(SPACE_CHARACTERS)
            return @data[old_position ... @data.position]
          rescue EOF
            #Return the whole remaining value
            return @data[old_position .. -1]
          end
        end
      rescue EOF
        return nil
      end
    end
  end

  # Determine if a string is a supported encoding
  def self.is_valid_encoding(encoding)
    (not encoding.nil? and encoding.kind_of?(String) and ENCODINGS.include?(encoding.downcase.strip))
  end

end
