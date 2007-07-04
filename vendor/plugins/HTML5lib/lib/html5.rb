require 'html5/html5parser'

module HTML5
    def self.parse(stream, options={})
        HTMLParser.parse(stream, options)
    end

    def self.parseFragment(stream, options={})
        HTMLParser.parse(stream, options)
    end
end
