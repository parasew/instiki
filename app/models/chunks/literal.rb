require 'chunks/chunk'

# These are basic chunks that have a pattern and can be protected.
# They are used by rendering process to prevent wiki rendering
# occuring within literal areas such as <code> and <pre> blocks
# and within HTML tags.
module Literal

  class AbstractLiteral < Chunk::Abstract

    def initialize(match_data, content)
      super
      @unmask_text = @text
    end

  end

  # A literal chunk that protects 'code' and 'pre' tags from wiki rendering.
  class Pre < AbstractLiteral
    PRE_BLOCKS = "a|pre|code"
    PRE_PATTERN = Regexp.new('<('+PRE_BLOCKS+')\b[^>]*?>.*?</\1>', Regexp::MULTILINE)
    def self.pattern() PRE_PATTERN end
  end 

  # A literal chunk that protects HTML tags from wiki rendering.
  class Tags < AbstractLiteral
    TAGS = "a|img|em|strong|div|span|table|td|th|ul|ol|li|dl|dt|dd"
    TAGS_PATTERN = Regexp.new('<(?:'+TAGS+')[^>]*?>', Regexp::MULTILINE) 
    def self.pattern() TAGS_PATTERN  end
  end
end
