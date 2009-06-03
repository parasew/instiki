require 'chunks/wiki'

#      [[!redirects Foo]]
# redirects Wikilinks for the (nonexistent) page "Foo" to this page.
# If "Foo" exists, then the Redirect has no effect. But if "Foo"
# does not exist, then a Wikilink [[Foo]] will produce a link to this
# page, rather than produce a create-a-new-page link. 

class Redirect < WikiChunk::WikiReference

  REDIRECT_PATTERN = /\[\[!redirects\s+([^\]\s][^\]]*?)\s*\]\]/i
  def self.pattern() REDIRECT_PATTERN end

  def initialize(match_data, content)
      super
      @page_name = match_data[1].strip
      @link_type = :redirect
      @unmask_text = ''
  end

end
