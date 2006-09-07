require 'chunks/wiki'

# Includes the contents of another page for rendering.
# The include command looks like this: "[[!include PageName]]".
# It is a WikiReference since it refers to another page (PageName)
# and the wiki content using this command must be notified
# of changes to that page.
# If the included page could not be found, a warning is displayed.

class Include < WikiChunk::WikiReference

  INCLUDE_PATTERN = /\[\[!include\s+(.*?)\]\]\s*/i
  def self.pattern() INCLUDE_PATTERN end

  def initialize(match_data, content)
    super
    @page_name = match_data[1].strip
    rendering_mode = content.options[:mode] || :show
    @unmask_text = get_unmask_text_avoiding_recursion_loops(rendering_mode)
  end

  private
  
  def get_unmask_text_avoiding_recursion_loops(rendering_mode)
    if refpage
      # TODO This way of instantiating a renderer is ugly.
      renderer = PageRenderer.new(refpage.current_revision)
      if renderer.wiki_includes.include?(@content.page_name)
        # this will break the recursion
        @content.delete_chunk(self)
        return "<em>Recursive include detected; #{@page_name} --> #{@content.page_name} " + 
               "--> #{@page_name}</em>\n"
      else
        included_content =
          case rendering_mode
          when :show then renderer.display_content
          when :publish then renderer.display_published
          when :export then renderer.display_content_for_export
          else raise "Unsupported rendering mode #{@mode.inspect}"
          end
        @content.merge_chunks(included_content)
        return included_content.pre_rendered
      end
    else
      return "<em>Could not include #{@page_name}</em>\n"
    end
  end

end
