require 'chunks/chunk'

# The category chunk looks for "category: news" on a line by
# itself and parses the terms after the ':' as categories.
# Other classes can search for Category chunks within
# rendered content to find out what categories this page
# should be in.
#
# Category lines can be hidden using ':category: news', for example
class Category < Chunk::Abstract
  def self.pattern() return /^(:)?category\s*:(.*)$/i end

  attr_reader :hidden, :list

  def initialize(match_data)
    super(match_data)
	@hidden = match_data[1]
    @list = match_data[2].split(',').map { |c| c.strip }
  end

  # Mark this chunk's start and end points but allow the terms
  # after the ':' to be marked up.
  def mask(content) pre_mask + list.join(', ') + post_mask end

  # If the chunk is hidden, erase the mask and return this chunk
  # otherwise, surround it with a 'div' block.
  def unmask(content)
	replacement = ( hidden ? '' : '<div class="property">category:\1</div>' )
    self if content.sub!( Regexp.new( pre_mask+'(.*)?'+post_mask ), replacement )
  end
end
