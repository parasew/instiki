require 'html5/html5parser'
require 'html5/version'

module HTML5

  def self.parse(stream, options={})
    HTMLParser.parse(stream, options)
  end

  def self.parse_fragment(stream, options={})
    HTMLParser.parse(stream, options)
  end
end
