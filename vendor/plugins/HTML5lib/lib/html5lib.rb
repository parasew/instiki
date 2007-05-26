require 'html5lib/html5parser'

module HTML5lib
    def self.parse(stream, options={})
        HTMLParser.parse(stream, options)
    end

    def self.parseFragment(stream, options={})
        HTMLParser.parse(stream, options)
    end
end
