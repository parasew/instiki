require 'chunks/chunk'

# This wiki chunk matches arbitrary URIs, using patterns from the Ruby URI modules.
# It parses out a variety of fields that could be used by renderers to format
# the links in various ways (shortening domain names, hiding email addresses)
# It matches email addresses and host.com.au domains without schemes (http://)
# but adds these on as required.
#
# The heuristic used to match a URI is designed to err on the side of caution.
# That is, it is more likely to not autolink a URI than it is to accidently
# autolink something that is not a URI. The reason behind this is it is easier
# to force a URI link by prefixing 'http://' to it than it is to escape and
# incorrectly marked up non-URI.
#
# I'm using a part of the [ISO 3166-1 Standard][iso3166] for country name suffixes.
# The generic names are from www.bnoack.com/data/countrycode2.html)
#   [iso3166]: http://geotags.com/iso3166/
class URIChunk < Chunk::Abstract
  include URI::REGEXP::PATTERN

  # this condition is to get rid of pesky warnings in tests
  unless defined? URI_CHUNK_CONSTANTS_DEFINED
    URI_CHUNK_CONSTANTS_DEFINED = true

    GENERIC = '(?:aero|biz|com|coop|edu|gov|info|int|mil|museum|name|net|org)'
    COUNTRY = '(?:au|at|be|ca|ch|de|dk|fr|hk|in|ir|it|jp|nl|no|pt|ru|se|sw|tv|tw|uk|us)'
  
    # These are needed otherwise HOST will match almost anything
    TLDS = "(?:#{GENERIC}|#{COUNTRY})"
    
    # Redefine USERINFO so that it must have non-zero length
    USERINFO = "(?:[#{UNRESERVED};:&=+$,]|#{ESCAPED})+"
  
    # unreserved_no_ending = alphanum | mark, but URI_ENDING [)!] excluded
    UNRESERVED_NO_ENDING = "-_.~*'(#{ALNUM}"  

    # this ensures that query or fragment do not end with URI_ENDING
    # and enable us to use a much simpler self.pattern Regexp

    # uric_no_ending = reserved | unreserved_no_ending | escaped
    URIC_NO_ENDING = "(?:[#{UNRESERVED_NO_ENDING}#{RESERVED}]|#{ESCAPED})"
    # query = *uric
    QUERY = "#{URIC_NO_ENDING}*"
    # fragment = *uric
    FRAGMENT = "#{URIC_NO_ENDING}*"

    # DOMLABEL is defined in the ruby uri library, TLDS is defined above
    FULL_HOSTNAME = "(?:#{DOMLABEL}\\.)+#{TLDS}" 

    # Correct a typo bug in ruby 1.8.x lib/uri/common.rb 
    PORT = '\\d*'

    URI_PATTERN =
        "(?:(#{SCHEME}):/{0,2})?" + # Optional scheme:        (\1)
        "(?:(#{USERINFO})@)?" +     # Optional userinfo@      (\2)
        "(#{FULL_HOSTNAME})" +      # Mandatory hostname      (\3)
        "(?::(#{PORT}))?" +         # Optional :port          (\4)
        "(#{ABS_PATH})?"  +         # Optional absolute path  (\5)
        "(?:\\?(#{QUERY}))?" +      # Optional ?query         (\6)
        "(?:\\#(#{FRAGMENT}))?"     # Optional #fragment      (\7)
  end

  def self.pattern()
    Regexp.new(URI_PATTERN, Regexp::EXTENDED, 'N')
  end

  attr_reader :uri, :scheme, :user, :host, :port, :path, :query, :fragment, :link_text
  
  def initialize(match_data)
    super(match_data)
    @scheme, @user, @host, @port, @path, @query, @fragment = match_data[1..-1]

    # If there is no scheme, add an appropriate one, otherwise
    # set the URI to the matched text.
	@text_scheme = scheme
    @uri = (scheme ? match_data[0] : nil )
    @scheme = scheme || ( user ? 'mailto' : 'http' )
    @delimiter = ( scheme == 'mailto' ? ':' : '://' ) 
    @uri ||= scheme + @delimiter + match_data[0]

    # Build up the link text. Schemes are omitted unless explicitly given.
	@link_text = ''
      @link_text << "#{@scheme}#{@delimiter}" if @text_scheme
      @link_text << "#{@user}@" if @user
      @link_text << "#{@host}" if @host
      @link_text << ":#{@port}" if @port
      @link_text << "#{@path}" if @path
      @link_text << "?#{@query}" if @query
  end

  # If the text should be escaped then don't keep this chunk.
  # Otherwise only keep this chunk if it was substituted back into the
  # content.
  def unmask(content)
    return nil if escaped_text
    return self if content.sub!( Regexp.new(mask(content)), "<a href=\"#{uri}\">#{link_text}</a>" )
  end

  # If there is no hostname in the URI, do not render it
  # It's probably only contains the scheme, eg 'something:' 
  def escaped_text() ( host.nil? ? @uri : nil )  end
end
