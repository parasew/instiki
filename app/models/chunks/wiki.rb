require 'wiki_words'
require 'chunks/chunk'
require 'chunks/wiki'
require 'cgi'

# Contains all the methods for finding and replacing wiki related links.
module WikiChunk
  include Chunk

  # A wiki reference is the top-level class for anything that refers to
  # another wiki page.
  class WikiReference < Chunk::Abstract

    # Name of the referenced page
    attr_reader :page_name
    
    # the referenced page
    def refpage
      @content.web.pages[@page_name]
    end
  
  end

  # A wiki link is the top-level class for links that refers to
  # another wiki page.
  class WikiLink < WikiReference
 
    attr_reader :link_text, :link_type

    def initialize(match_data, content)
      super
      @link_type = :show
    end

    def self.apply_to(content)
      content.gsub!( self.pattern ) do |matched_text|
        chunk = self.new($~, content)
        if chunk.textile_url?
          # do not substitute
          matched_text
        else
          content.add_chunk(chunk)
          chunk.mask
        end
      end
    end

    # the referenced page
    def refpage
      @content.web.pages[@page_name]
    end

    def textile_url?
      not @textile_link_suffix.nil?
    end

  end

  # This chunk matches a WikiWord. WikiWords can be escaped
  # by prepending a '\'. When this is the case, the +escaped_text+
  # method will return the WikiWord instead of the usual +nil+.
  # The +page_name+ method returns the matched WikiWord.
  class Word < WikiLink

    attr_reader :escaped_text
    
    unless defined? WIKI_WORD
      WIKI_WORD = Regexp.new('(":)?(\\\\)?(' + WikiWords::WIKI_WORD_PATTERN + ')\b', 0, "utf-8")
    end

    def self.pattern
      WIKI_WORD
    end

    def initialize(match_data, content)
      super
      @textile_link_suffix, @escape, @page_name = match_data[1..3]
      if @escape 
        @unmask_mode = :escape
        @escaped_text = @page_name
      else
        @escaped_text = nil
      end
      @link_text = WikiWords.separate(@page_name)
      @unmask_text = (@escaped_text || @content.page_link(@page_name, @link_text, @link_type))
    end

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
    
    unless defined? WIKI_LINK
      WIKI_LINK = /(":)?\[\[([^\]]+)\]\]/
      LINK_TYPE_SEPARATION = Regexp.new('^(.+):((file)|(pic))$', 0, 'utf-8')
      ALIAS_SEPARATION = Regexp.new('^(.+)\|(.+)$', 0, 'utf-8')
    end    
        
    def self.pattern() WIKI_LINK end

    def initialize(match_data, content)
      super
      @textile_link_suffix, @page_name = match_data[1..2]
      @link_text = @page_name
      separate_link_type
      separate_alias
      @unmask_text = @content.page_link(@page_name, @link_text, @link_type)
    end

    private

    # if link wihin the brackets has a form of [[filename:file]] or [[filename:pic]], 
    # this means a link to a picture or a file
    def separate_link_type
      link_type_match = LINK_TYPE_SEPARATION.match(@page_name)
      if link_type_match
        @link_text = @page_name = link_type_match[1]
        @link_type = link_type_match[2..3].compact[0].to_sym
      end
    end

    # link text may be different from page name. this will look like [[actual page|link text]]
    def separate_alias
      alias_match = ALIAS_SEPARATION.match(@page_name)
      if alias_match
        @page_name, @link_text = alias_match[1..2]
      end
      # note that [[filename|link text:file]] is also supported
    end  
  
  end
  
end
