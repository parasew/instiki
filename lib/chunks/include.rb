require 'chunks/wiki'

# Includes the contents of another page for rendering.
# The include command looks like this: "[[!include PageName]]".
# It is a WikiReference since it refers to another page (PageName)
# and the wiki content using this command must be notified
# of changes to that page.
# If the included page could not be found, a warning is displayed.

class Include < WikiChunk::WikiReference

  INCLUDE_PATTERN = /\[\[!include\s+([^\]\s][^\]]+?)\s*\]\]/i
  Thread.current[:included_by] = []
  def self.pattern() INCLUDE_PATTERN end

  def initialize(match_data, content)
    super
    @page_name = match_data[1].strip
    rendering_mode = content.options[:mode] || :show
    Thread.current[:included_by].push(@content.page_name)
    @unmask_text = get_unmask_text_avoiding_recursion_loops(rendering_mode)
  end

  private
  
  def get_unmask_text_avoiding_recursion_loops(rendering_mode)
    if refpage      
      if Thread.current[:included_by].include?(refpage.page.name)
        @content.delete_chunk(self)
        Thread.current[:included_by] = []
        return "<em>Recursive include detected: #{@content.page_name} &#x2192; #{@content.page_name}</em>\n"
      end
      # TODO This way of instantiating a renderer is ugly.
      renderer = PageRenderer.new(refpage.current_revision)
      included_content =
        case rendering_mode
          when :show then renderer.display_content
          when :publish then renderer.display_published
          when :export then renderer.display_content_for_export
        else
          raise "Unsupported rendering mode #{@mode.inspect}"
        end
      @content.merge_chunks(included_content)
      Thread.current[:included_by] = []
      return included_content.pre_rendered
    else
      Thread.current[:included_by] = []
      return "<em>Could not include #{@page_name}</em>\n"
    end
  end

end
