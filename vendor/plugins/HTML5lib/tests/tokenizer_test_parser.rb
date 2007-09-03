require 'html5/constants'

class TokenizerTestParser
  def initialize(tokenizer)
    @tokenizer = tokenizer
  end

  def parse
    @outputTokens = []

    debug = nil
    for token in @tokenizer
      debug = token.inspect if token[:type] == :ParseError
      send(('process' + token[:type].to_s), token)
    end

    return @outputTokens
  end

  def processDoctype(token)
    @outputTokens.push(["DOCTYPE", token[:name], token[:publicId],
      token[:systemId], token[:correct]])
  end

  def processStartTag(token)
    @outputTokens.push(["StartTag", token[:name], token[:data]])
  end

  def processEmptyTag(token)
    if not HTML5::VOID_ELEMENTS.include? token[:name]
      @outputTokens.push("ParseError")
    end
    @outputTokens.push(["StartTag", token[:name], token[:data]])
  end

  def processEndTag(token)
    if token[:data].length > 0
      self.processParseError(token)
    end
    @outputTokens.push(["EndTag", token[:name]])
  end

  def processComment(token)
    @outputTokens.push(["Comment", token[:data]])
  end

  def processCharacters(token)
    @outputTokens.push(["Character", token[:data]])
  end

  alias processSpaceCharacters processCharacters

  def processCharacters(token)
    @outputTokens.push(["Character", token[:data]])
  end

  def process_eof(token)
  end

  def processParseError(token)
    @outputTokens.push("ParseError")
  end
end
