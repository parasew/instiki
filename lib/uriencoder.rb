# URI path and fragment escaping
# https://tools.ietf.org/html/rfc3986
# from actionpack/lib/action_dispatch/journey/router/utils.rb
class UriEncoder # :nodoc:
  ENCODE   = "%%%02X".freeze
  US_ASCII = Encoding::US_ASCII
  UTF_8    = Encoding::UTF_8
  EMPTY    = "".dup.force_encoding(US_ASCII).freeze
  DEC2HEX  = (0..255).to_a.map { |i| ENCODE % i }.map { |s| s.force_encoding(US_ASCII) }

  ALPHA = "a-zA-Z".freeze
  DIGIT = "0-9".freeze
  UNRESERVED = "#{ALPHA}#{DIGIT}\\-\\._~".freeze
  SUB_DELIMS = "!\\$&'\\(\\)\\*\\+,;=".freeze

  ESCAPED  = /%[a-zA-Z0-9]{2}/.freeze

  FRAGMENT = /[^#{UNRESERVED}#{SUB_DELIMS}:@\/\?]/.freeze
  SEGMENT  = /[^#{UNRESERVED}#{SUB_DELIMS}:@]/.freeze
  PATH     = /[^#{UNRESERVED}#{SUB_DELIMS}:@\/]/.freeze

  def self.escape_fragment(fragment)
    self.escape(fragment, FRAGMENT)
  end

  def self.escape_path(path)
    self.escape(path, PATH)
  end

  def self.escape_segment(segment)
    self.escape(segment, SEGMENT)
  end

  def unescape_uri(uri)
    encoding = uri.encoding == US_ASCII ? UTF_8 : uri.encoding
    uri.gsub(ESCAPED) { |match| [match[1, 2].hex].pack("C") }.force_encoding(encoding)
  end

  def self.escape(component, pattern)
    component.gsub(pattern) { |unsafe| percent_encode(unsafe) }.force_encoding(US_ASCII)
  end

  private
    def percent_encode(unsafe)
      safe = EMPTY.dup
      unsafe.each_byte { |b| safe << DEC2HEX[b] }
      safe
    end
end
