require 'wiki_words'
require 'chunks/chunk'
require 'chunks/wiki'
require 'cgi'

# Contains all the methods for finding and replacing wiki related
# links.
module WikiChunk
  include Chunk

  # A wiki link is the top-level class for anything that refers to
  # another wiki page.
  class WikiLink < Chunk::Abstract
    # By default, no escaped text
    def escaped_text() nil end

    # Delimit the link text with markers to replace later unless
    # the word is escaped. In that case, just return the link text
    def mask(content) escaped_text || pre_mask + link_text + post_mask end

    def regexp() /#{pre_mask}(.*)?#{post_mask}/ end

    def revert(content) content.sub!(regexp, text) end

    # Do not keep this chunk if it is escaped.
    # Otherwise, pass the link procedure a page_name and link_text and
    # get back a string of HTML to replace the mask with.
    def unmask(content)
      return nil if escaped_text
      return self if content.sub!(regexp) do |match|
        content.page_link(page_name, $1)
      end
    end
  end

  # This chunk matches a WikiWord. WikiWords can be escaped
  # by prepending a '\'. When this is the case, the +escaped_text+
  # method will return the WikiWord instead of the usual +nil+.
  # The +page_name+ method returns the matched WikiWord.
  class Word < WikiLink
    unless defined? WIKI_LINK
      WIKI_WORD = Regexp.new('(\\\\)?(' + WikiWords::WIKI_WORD_PATTERN + ')\b', 0, "utf-8")
    end
    
    def self.pattern
      WIKI_WORD
    end

    attr_reader :page_name

    def initialize(match_data)
      super(match_data)
      @escape = match_data[1]
      @page_name = match_data[2]
    end

    def escaped_text() (@escape.nil? ? nil : page_name) end
    def link_text() WikiWords.separate(page_name) end	
  end

  # This chunk handles [[bracketted wiki words]] and 
  # [[AliasedWords|aliased wiki words]]. The first part of an
  # aliased wiki word must be a WikiWord. If the WikiWord
  # is aliased, the +link_text+ field will contain the
  # alias, otherwise +link_text+ will contain the entire
  # contents within the double brackets.
  #
  # NOTE: This chunk must be tested before WikiWord since
  #       a WikiWords can be a substring of a WikiLink. 
  class Link < WikiLink
    
    WIKI_LINK = /\[\[([^\]]+)\]\]/ unless defined? WIKI_LINK
    ALIASED_LINK_PATTERN = 
        Regexp.new('^(.*)?\|(.*)$', 0, 'utf-8') unless defined? ALIASED_LINK_PATTERN

    def self.pattern() WIKI_LINK end

    attr_reader :page_name, :link_text

    def initialize(match_data)
      super(match_data)

	  # If the like is aliased, set the page name to the first bit
	  # and the link text to the second, otherwise set both to the
	  # contents of the double brackets.
      if match_data[1] =~ ALIASED_LINK_PATTERN
        @page_name, @link_text = $1, $2
      else
        @page_name, @link_text = match_data[1], match_data[1]
      end
    end
  end
end
