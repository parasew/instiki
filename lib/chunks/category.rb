require 'chunks/chunk'
require 'instiki_stringsupport'

# The category chunk looks for "category: news" on a line by
# itself and parses the terms after the ':' as categories.
# Other classes can search for Category chunks within
# rendered content to find out what categories this page
# should be in.
#
# Category lines can be hidden using ':category: news', for example
class Category < Chunk::Abstract

  CATEGORY_PATTERN = /^(:)?category\s*:(.*)$/i
  def self.pattern() CATEGORY_PATTERN  end

  attr_reader :hidden, :list

def initialize(match_data, content)
    super(match_data, content)
    @content = content
    @hidden = match_data[1]
    @list = match_data[2].split(',').map { |c| clean = c.purify.strip.escapeHTML; clean if clean != ''}
    @list.compact!
    @unmask_text = ''
    if @hidden
      @unmask_text = ''
    else
      category_urls = @list.map { |category| url(category) }.join(', ')
      @unmask_text = '<div class="property"> category: ' + category_urls + '</div>'
    end
  end

  # TODO move presentation of page metadata to controller/view
  def url(category)
    %{<a class="category_link" href="#{@content.url_generator.url_for :web => @content.web.address,
                    :action => 'list', :only_path => true}/#{CGI.escape(category)}">#{category}</a>}
  end
end
