require 'chunks/chunk'
require 'instiki_stringsupport'

# Contains all the methods for finding and replacing wiki related links.
module WikiChunk
  include Chunk

  # A wiki reference is the top-level class for anything that refers to
  # another wiki page.
  class WikiReference < Chunk::Abstract

    # Name of the referenced page
    attr_reader :page_name

    # Name of the referenced page
    attr_reader :web_name

    # the referenced page
    def refpage
      @content.web.page(@page_name)
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
      content.as_utf8.gsub!( self.pattern ) do |matched_text|
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

    def textile_url?
      not @textile_link_suffix.nil?
    end

    def interweb_link?
      not @web_name.nil? and Web.find_by_name(@web_name) or
        Web.find_by_address(@web_name)
    end

    # replace any sequence of whitespace characters with a single space
    def normalize_whitespace(line)
      line.gsub(/\s+/, ' ')
    end

  end

  # This chunk matches a WikiWord. WikiWords can be escaped
  # by prepending a '\'. When this is the case, the +escaped_text+
  # method will return the WikiWord instead of the usual +nil+.
  # The +page_name+ method returns the matched WikiWord.
  class Word < WikiLink

    attr_reader :escaped_text

    unless defined? WIKI_WORD
      WIKI_WORD = ''.respond_to?(:force_encoding) ? 
            Regexp.new('(":)?(\\\\)?(' + WikiWords::WIKI_WORD_PATTERN + ')\b', 0) :
            Regexp.new('(":)?(\\\\)?(' + WikiWords::WIKI_WORD_PATTERN + ')\b', 0, 'u')
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
      @unmask_text = (@escaped_text || @content.page_link(@web_name, @page_name, @link_text, @link_type))
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
      WIKI_LINK = /(":)?\[\[\s*([^\]\s][^\]]*?)\s*\]\]/
      LINK_TYPE_SEPARATION = Regexp.new('^(.+):((file)|(pic)|(video)|(audio)|(delete))$', 0)
      ALIAS_SEPARATION = Regexp.new('^(.+)\|(.+)$', 0)
      WEB_SEPARATION = Regexp.new('^(.+):(.+)$', 0)
    end

    def self.pattern() WIKI_LINK end

    def initialize(match_data, content)
      super
      @textile_link_suffix = match_data[1]
      @link_text = @page_name = normalize_whitespace(match_data[2])
      separate_link_type
      separate_alias
      separate_web
      @unmask_text = @content.page_link(@web_name, @page_name, @link_text, @link_type)
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
        @page_name = normalize_whitespace(alias_match[1])
        @link_text = alias_match[2]
      end
      # note that [[filename|link text:file]] is also supported
    end

    # Interweb links have the form [[Web Name:Page Name]] or
    # [[address:PageName]]. Alternate text links of the form
    # [[address:PageName|Other text]] are also supported.
    def separate_web
      web_match = WEB_SEPARATION.match(@page_name)
      if web_match
        @web_name = normalize_whitespace(web_match[1])
        @page_name = web_match[2]
        @link_text = @page_name if @link_text == web_match[0]
      end
    end

  end

end
