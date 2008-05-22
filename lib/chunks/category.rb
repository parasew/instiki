require 'chunks/chunk'
require 'stringsupport'

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
    @hidden = match_data[1]
    @list = match_data[2].split(',').map { |c| c.to_s.is_utf8? ? c.strip.escapeHTML : nil }
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
    %{<a class="category_link" href="../list/#{category}">#{category}</a>}
  end
end
