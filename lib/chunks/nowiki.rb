require 'chunks/chunk'
require 'sanitize'
require 'rexml/document'

# This chunks allows certain parts of a wiki page to be hidden from the
# rest of the rendering pipeline. It should be run at the beginning
# of the pipeline in `wiki_content.rb`.
#
# An example use of this chunk is to markup double brackets or
# auto URI links:
#  <nowiki>Here are [[double brackets]] and a URI: www.uri.org</nowiki>
#
# The contents of the chunks will not be processed by any other chunk
# so the `www.uri.org` and the double brackets will appear verbatim.
#
# Author: Mark Reid <mark at threewordslong dot com>
# Created: 8th June 2004

class NoWiki < Chunk::Abstract

  include Sanitize
  
  NOWIKI_PATTERN = Regexp.new('<nowiki>(.*?)</nowiki>', Regexp::MULTILINE)
  def self.pattern() NOWIKI_PATTERN end

  attr_reader :plain_text

  def initialize(match_data, content)
    super
    begin
      sanitized = sanitize_xhtml(match_data[1])
      doc = REXML::Document.new("<div xmlns='http://www.w3.org/1999/xhtml'>#{sanitized}</div>")
      sanitized = doc.to_s.gsub(/\A<div xmlns='http:\/\/www.w3.org\/1999\/xhtml'>(.*)<\/div>\Z/m, '\1')
    rescue REXML::ParseException
      sanitized = %{<pre class='markdown-html-error' style='border: solid 3px red; background-color: pink;'>HTML parse error:
#{sanitized.escapeHTML}</pre>}
    end
    @plain_text = @unmask_text = sanitized
  end

end
