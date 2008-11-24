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
  unless defined? URIChunk::INTERNET_URI_REGEXP

    GENERIC = 'aero|biz|com|coop|edu|gov|info|int|mil|museum|name|net|org'
    
    COUNTRY = 'ad|ae|af|ag|ai|al|am|an|ao|aq|ar|as|at|au|aw|az|ba|bb|bd|be|' + 
      'bf|bg|bh|bi|bj|bm|bn|bo|br|bs|bt|bv|bw|by|bz|ca|cc|cf|cd|cg|ch|ci|ck|cl|' + 
      'cm|cn|co|cr|cs|cu|cv|cx|cy|cz|de|dj|dk|dm|do|dz|ec|ee|eg|eh|er|es|et|fi|' + 
      'fj|fk|fm|fo|fr|fx|ga|gb|gd|ge|gf|gh|gi|gl|gm|gn|gp|gq|gr|gs|gt|gu|gw|gy|' + 
      'hk|hm|hn|hr|ht|hu|id|ie|il|in|io|iq|ir|is|it|jm|jo|jp|ke|kg|kh|ki|km|kn|' + 
      'kp|kr|kw|ky|kz|la|lb|lc|li|lk|lr|ls|lt|lu|lv|ly|ma|mc|md|mg|mh|mk|ml|mm|' + 
      'mn|mo|mp|mq|mr|ms|mt|mu|mv|mw|mx|my|mz|na|nc|ne|nf|ng|ni|nl|no|np|nr|nt|' + 
      'nu|nz|om|pa|pe|pf|pg|ph|pk|pl|pm|pn|pr|pt|pw|py|qa|re|ro|ru|rw|sa|sb|sc|' + 
      'sd|se|sg|sh|si|sj|sk|sl|sm|sn|so|sr|st|su|sv|sy|sz|tc|td|tf|tg|th|tj|tk|' + 
      'tm|tn|to|tp|tr|tt|tv|tw|tz|ua|ug|uk|um|us|uy|uz|va|vc|ve|vg|vi|vn|vu|wf|' + 
      'ws|ye|yt|yu|za|zm|zr|zw'
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
    INTERNET_HOSTNAME = "(?:#{DOMLABEL}\\.)+#{TLDS}" 

    # Correct a typo bug in ruby 1.8.x lib/uri/common.rb 
    PORT = '\\d*'

    INTERNET_URI =
        "(?:(#{SCHEME}):/{0,2})?" +   # Optional scheme:        (\1)
        "(?:(#{USERINFO})@)?" +       # Optional userinfo@      (\2)
        "(#{INTERNET_HOSTNAME})" +    # Mandatory hostname      (\3)
        "(?::(#{PORT}))?" +           # Optional :port          (\4)
        "(#{ABS_PATH})?"  +           # Optional absolute path  (\5)
        "(?:\\?(#{QUERY}))?" +        # Optional ?query         (\6)
        "(?:\\#(#{FRAGMENT}))?"  +    # Optional #fragment      (\7)
        '(?=\.?(?:\s|\)|\z))'         # ends only with optional dot + space or ")" 
                                      # or end of the string

    SUSPICIOUS_PRECEDING_CHARACTER = '(!|\"\:|\"|\\\'|\]\()?'  # any of !, ":, ", ', ](
  
    INTERNET_URI_REGEXP = 
#        Regexp.new(SUSPICIOUS_PRECEDING_CHARACTER + INTERNET_URI, Regexp::EXTENDED, 'N')
        Regexp.new(SUSPICIOUS_PRECEDING_CHARACTER + INTERNET_URI, Regexp::EXTENDED)

  end

  def URIChunk.pattern
    INTERNET_URI_REGEXP
  end

  attr_reader :user, :host, :port, :path, :query, :fragment, :link_text
  
  def self.apply_to(content)
    content.gsub!( self.pattern ) do |matched_text|
      chunk = self.new($~, content)
      if chunk.avoid_autolinking?
        # do not substitute nor register the chunk
        matched_text
      else
        content.add_chunk(chunk)
        chunk.mask
      end
    end
  end

  def initialize(match_data, content)
    super
    @link_text = match_data[0]
    @suspicious_preceding_character = match_data[1]
    @original_scheme, @user, @host, @port, @path, @query, @fragment = match_data[2..-1]
    treat_trailing_character
    @unmask_text = "<a href=\"#{uri}\">#{link_text}</a>"
  end

  def avoid_autolinking?
    not @suspicious_preceding_character.nil?
  end

  def treat_trailing_character
    # If the last character matched by URI pattern is in ! or ), this may be part of the markup,
    # not a URL. We should handle it as such. It is possible to do it by a regexp, but 
    # much easier to do programmatically
    last_char = @link_text[-1..-1]
    if last_char == ')' or last_char == '!'
      @trailing_punctuation = last_char
      @link_text.chop!
      [@original_scheme, @user, @host, @port, @path, @query, @fragment].compact.last.chop!
    else 
      @trailing_punctuation = nil
    end
  end

  def scheme
    @original_scheme or (@user ? 'mailto' : 'http')
  end

  def scheme_delimiter
    scheme == 'mailto' ? ':' : '://'
  end

  def user_delimiter
     '@' unless @user.nil?
  end

  def port_delimiter
     ':' unless @port.nil?
  end

  def query_delimiter
     '?' unless @query.nil?
  end

  def uri
    [scheme, scheme_delimiter, user, user_delimiter, host, port_delimiter, port, path, 
      query_delimiter, query].compact.join
  end

end

# uri with mandatory scheme but less restrictive hostname, like
# http://localhost:2500/blah.html
class LocalURIChunk < URIChunk

  unless defined? LocalURIChunk::LOCAL_URI_REGEXP
    # hostname can be just a simple word like 'localhost'
    ANY_HOSTNAME = "(?:#{DOMLABEL}\\.)*#{TOPLABEL}\\.?"
    
    # The basic URI expression as a string
    # Scheme and hostname are mandatory
    LOCAL_URI =
        "(?:(#{SCHEME})://)+" +       # Mandatory scheme://     (\1)
        "(?:(#{USERINFO})@)?" +       # Optional userinfo@      (\2)
        "(#{ANY_HOSTNAME})" +         # Mandatory hostname      (\3)
        "(?::(#{PORT}))?" +           # Optional :port          (\4)
        "(#{ABS_PATH})?"  +           # Optional absolute path  (\5)
        "(?:\\?(#{QUERY}))?" +        # Optional ?query         (\6)
        "(?:\\#(#{FRAGMENT}))?" +     # Optional #fragment      (\7)
        '(?=\.?(?:\s|\)|\z))'         # ends only with optional dot + space or ")" 
                                      # or end of the string
  
#    LOCAL_URI_REGEXP = Regexp.new(SUSPICIOUS_PRECEDING_CHARACTER + LOCAL_URI, Regexp::EXTENDED, 'N')
    LOCAL_URI_REGEXP = Regexp.new(SUSPICIOUS_PRECEDING_CHARACTER + LOCAL_URI, Regexp::EXTENDED)
  end

  def LocalURIChunk.pattern
    LOCAL_URI_REGEXP
  end

end
