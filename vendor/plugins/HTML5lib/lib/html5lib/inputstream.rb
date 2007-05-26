require 'stringio'
require 'html5lib/constants'

module HTML5lib

# Provides a unicode stream of characters to the HTMLTokenizer.

# This class takes care of character encoding and removing or replacing
# incorrect byte-sequences and also provides column and line tracking.

class HTMLInputStream

    attr_accessor :queue, :charEncoding

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
        @encoding = nil
        @parseMeta = true
        @chardet = true

        options.each { |name, value| instance_variable_set("@#{name}", value) }

        # List of where new lines occur
        @newLines = []

        # Raw Stream
        @rawStream = openStream(source)

        # Encoding Information
        #Number of bytes to use when looking for a meta element with
        #encoding information
        @NUM_BYTES_META = 512
        #Encoding to use if no other information can be found
        @DEFAULT_ENCODING = 'windows-1252'
        
        #Detect encoding iff no explicit "transport level" encoding is supplied
        if @encoding.nil? or not HTML5lib.isValidEncoding(@encoding)
            @charEncoding = detectEncoding
        else
            @charEncoding = @encoding
        end

        # Read bytes from stream decoding them into Unicode
        uString = @rawStream.read
        unless @charEncoding == 'utf-8'
            begin
                require 'iconv'
                uString = Iconv.iconv('utf-8', @encoding, uString)[0]
            rescue
            end
        end

        # Normalize newlines and null characters
        uString.gsub!(/\r\n?/, "\n")
        uString.gsub!("\x00", [0xFFFD].pack('U'))

        # Convert the unicode string into a list to be used as the data stream
        @dataStream = uString

        @queue = []

        # Reset position in the list to read from
        reset
    end

    # Produces a file object from source.
    #
    # source can be either a file object, local filename or a string.
    def openStream(source)
        # Already an IO like object
        if source.respond_to?(:read)
            @stream = source
        else
            # Treat source as a string and wrap in StringIO
            @stream = StringIO.new(source)
        end
        return @stream
    end

    def detectEncoding

        #First look for a BOM
        #This will also read past the BOM if present
        encoding = detectBOM
        #If there is no BOM need to look for meta elements with encoding 
        #information
        if encoding.nil? and @parseMeta
            encoding = detectEncodingMeta
        end
        #Guess with chardet, if avaliable
        if encoding.nil? and @chardet
            begin
                require 'rubygems'
                require 'UniversalDetector' # gem install chardet
                buffer = @rawStream.read
                encoding = UniversalDetector::chardet(buffer)['encoding']
                @rawStream = openStream(buffer)
            rescue LoadError
            end
        end
        # If all else fails use the default encoding
        if encoding.nil?
            encoding = @DEFAULT_ENCODING
        end
        
        #Substitute for equivalent encodings:
        encodingSub = {'ascii' => 'windows-1252', 'iso-8859-1' => 'windows-1252'}

        if encodingSub.has_key?(encoding.downcase)
            encoding = encodingSub[encoding.downcase]
        end

        return encoding
    end

    # Attempts to detect at BOM at the start of the stream. If
    # an encoding can be determined from the BOM return the name of the
    # encoding otherwise return nil
    def detectBOM
        bomDict = {
            "\xef\xbb\xbf" => 'utf-8',
            "\xff\xfe" => 'utf-16-le',
            "\xfe\xff" => 'utf-16-be',
            "\xff\xfe\x00\x00" => 'utf-32-le',
            "\x00\x00\xfe\xff" => 'utf-32-be'
        }

        # Go to beginning of file and read in 4 bytes
        @rawStream.seek(0)
        string = @rawStream.read(4)
        return nil unless string

        # Try detecting the BOM using bytes from the string
        encoding = bomDict[string[0...3]]          # UTF-8
        seek = 3
        unless encoding
            # Need to detect UTF-32 before UTF-16
            encoding = bomDict[string]             # UTF-32
            seek = 4
            unless encoding
                encoding = bomDict[string[0...2]]  # UTF-16
                seek = 2
            end
        end

        #AT - move this to the caller?
        # Set the read position past the BOM if one was found, otherwise
        # set it to the start of the stream
        @rawStream.seek(encoding ? seek : 0)

        return encoding
    end

    # Report the encoding declared by the meta element
    def detectEncodingMeta
        parser = EncodingParser.new(@rawStream.read(@NUM_BYTES_META))
        @rawStream.seek(0)
        return parser.getEncoding
    end

    def determineNewLines
        # Looks through the stream to find where new lines occur so
        # the position method can tell where it is.
        @newLines.push(0)
        (0...@dataStream.length).each { |i| @newLines.push(i) if @dataStream[i] == ?\n }
    end

    # Returns (line, col) of the current position in the stream.
    def position
        # Generate list of new lines first time around
        determineNewLines if @newLines.empty?
        line = 0
        tell = @tell
        @newLines.each do |pos|
            break unless pos < tell
            line += 1
        end
        col = tell - @newLines[line-1] - 1
        return [line, col]
    end

    # Resets the position in the stream back to the start.
    def reset
        @tell = 0
    end

    # Read one character from the stream or queue if available. Return
    # EOF when EOF is reached.
    def char
        unless @queue.empty?
            return @queue.shift
        else
            begin
                @tell += 1
                return @dataStream[@tell - 1].chr
            rescue
                return :EOF
            end
        end
    end

    # Returns a string of characters from the stream up to but not
    # including any character in characters or EOF. characters can be
    # any container that supports the in method being called on it.
    def charsUntil(characters, opposite = false)
        charStack = [char]

        unless charStack[0] == :EOF
            while (characters.include? charStack[-1]) == opposite
                unless @queue.empty?
                    # First from the queue
                    charStack.push(@queue.shift)
                    break if charStack[-1] == :EOF
                else
                    # Then the rest
                    begin
                        charStack.push(@dataStream[@tell].chr)
                        @tell += 1
                    rescue
                        charStack.push(:EOF)
                        break
                    end
                end
            end
        end

        # Put the character stopped on back to the front of the queue
        # from where it came.
        @queue.insert(0, charStack.pop)
        return charStack.join('')
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
    
    def currentByte
        raise EOF if @position >= length
        return self[@position].chr
    end
    
    # Skip past a list of characters
    def skip(chars = SPACE_CHARACTERS)
        while chars.include?(currentByte)
            @position += 1
        end
    end

    # Look for a sequence of bytes at the start of a string. If the bytes 
    # are found return true and advance the position to the byte after the 
    # match. Otherwise return false and leave the position alone
    def matchBytes(bytes, lower = false)
        data = self[position ... position+bytes.length]
        data.downcase! if lower
        rv = (data == bytes)
        @position += bytes.length if rv == true
        return rv
    end
    
    # Look for the next sequence of bytes matching a given sequence. If
    # a match is found advance the position to the last byte of the match
    def jumpTo(bytes)
        newPosition = self[position .. -1].index(bytes)
        if newPosition
            @position += (newPosition + bytes.length-1)
            return true
        else
            raise EOF
        end
    end
    
    # Move the pointer so it points to the next byte in a set of possible
    # bytes
    def findNext(byteList)
        until byteList.include?(currentByte)
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
        ['<!--', :handleComment],
        ['<meta', :handleMeta],
        ['</', :handlePossibleEndTag],
        ['<!', :handleOther],
        ['<?', :handleOther],
        ['<', :handlePossibleStartTag]
    ]

    def getEncoding
        @data.each do |byte|
            keepParsing = true
            @@method_dispatch.each do |(key, method)|
                if @data.matchBytes(key, lower = true)
                    keepParsing = send(method)    
                    break
                end
            end
            break unless keepParsing
        end
        @encoding = @encoding.strip unless @encoding.nil?
        return @encoding
    end

    # Skip over comments
    def handleComment
        return @data.jumpTo('-->')
    end

    def handleMeta
        # if we have <meta not followed by a space so just keep going
        return true unless SPACE_CHARACTERS.include?(@data.currentByte)

        #We have a valid meta element we want to search for attributes
        while true
            #Try to find the next attribute after the current position
            attr = getAttribute

            return true if attr.nil?
                
            if attr[0] == 'charset'
                tentativeEncoding = attr[1]
                if HTML5lib.isValidEncoding(tentativeEncoding)
                    @encoding = tentativeEncoding    
                    return false
                end
            elsif attr[0] == 'content'
                contentParser = ContentAttrParser.new(EncodingBytes.new(attr[1]))
                tentativeEncoding = contentParser.parse
                if HTML5lib.isValidEncoding(tentativeEncoding)
                    @encoding = tentativeEncoding    
                    return false
                end
            end
        end
    end

    def handlePossibleStartTag
        return handlePossibleTag(false)
    end

    def handlePossibleEndTag
        @data.position+=1
        return handlePossibleTag(true)
    end

    def handlePossibleTag(endTag)
        unless ASCII_LETTERS.include?(@data.currentByte)
            #If the next byte is not an ascii letter either ignore this
            #fragment (possible start tag case) or treat it according to 
            #handleOther
            if endTag
                @data.position -= 1
                handleOther
            end
            return true
        end
        
        @data.findNext(SPACE_CHARACTERS + ['<', '>'])

        if @data.currentByte == '<'
            #return to the first step in the overall "two step" algorithm
            #reprocessing the < byte
            @data.position -= 1    
        else
            #Read all attributes
            {} until getAttribute.nil?
        end
        return true
    end

    def handleOther
        return @data.jumpTo('>')
    end

    # Return a name,value pair for the next attribute in the stream, 
    # if one is found, or nil
    def getAttribute
        @data.skip(SPACE_CHARACTERS + ['/'])

        if @data.currentByte == '<'
            @data.position -= 1
            return nil
        elsif @data.currentByte == '>'
            return nil
        end

        attrName = []
        attrValue = []
        spaceFound = false
        #Step 5 attribute name
        while true
            if @data.currentByte == '=' and attrName:   
                break
            elsif SPACE_CHARACTERS.include?(@data.currentByte)
                spaceFound = true
                break
            elsif ['/', '<', '>'].include?(@data.currentByte)
                return [attrName.join(''), '']
            elsif ASCII_UPPERCASE.include?(@data.currentByte)
                attrName.push(@data.currentByte.downcase)
            else
                attrName.push(@data.currentByte)
            end
            #Step 6
            @data.position += 1
        end
        #Step 7
        if spaceFound
            @data.skip
            #Step 8
            unless @data.currentByte == '='
                @data.position -= 1
                return [attrName.join(''), '']
            end
        end
        #XXX need to advance position in both spaces and value case
        #Step 9
        @data.position += 1
        #Step 10
        @data.skip
        #Step 11
        if ["'", '"'].include?(@data.currentByte)
            #11.1
            quoteChar = @data.currentByte
            while true
                @data.position+=1
                #11.3
                if @data.currentByte == quoteChar
                    @data.position += 1
                    return [attrName.join(''), attrValue.join('')]
                #11.4
                elsif ASCII_UPPERCASE.include?(@data.currentByte)
                    attrValue.push(@data.currentByte.downcase)
                #11.5
                else
                    attrValue.push(@data.currentByte)
                end
            end
        elsif ['>', '<'].include?(@data.currentByte)
            return [attrName.join(''), '']
        elsif ASCII_UPPERCASE.include?(@data.currentByte)
            attrValue.push(@data.currentByte.downcase)
        else
            attrValue.push(@data.currentByte)
        end
        while true
            @data.position +=1
            if (SPACE_CHARACTERS + ['>', '<']).include?(@data.currentByte)
                return [attrName.join(''), attrValue.join('')]
            elsif ASCII_UPPERCASE.include?(@data.currentByte)
                attrValue.push(@data.currentByte.downcase)
            else
                attrValue.push(@data.currentByte)
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
            @data.jumpTo(';')
            @data.position += 1
            @data.skip
            #Check if the attr name is charset 
            #otherwise return
            @data.jumpTo('charset')
            @data.position += 1
            @data.skip
            unless @data.currentByte == '='
                #If there is no = sign keep looking for attrs
                return nil
            end
            @data.position += 1
            @data.skip
            #Look for an encoding between matching quote marks
            if ['"', "'"].include?(@data.currentByte)
                quoteMark = @data.currentByte
                @data.position += 1
                oldPosition = @data.position
                @data.jumpTo(quoteMark)
                return @data[oldPosition ... @data.position]
            else
                #Unquoted value
                oldPosition = @data.position
                begin
                    @data.findNext(SPACE_CHARACTERS)
                    return @data[oldPosition ... @data.position]
                rescue EOF
                    #Return the whole remaining value
                    return @data[oldPosition .. -1]
                end
            end
        rescue EOF
            return nil
        end
    end
end

# Determine if a string is a supported encoding
def self.isValidEncoding(encoding)
    (not encoding.nil? and encoding.kind_of?(String) and ENCODINGS.include?(encoding.downcase.strip))
end

end
