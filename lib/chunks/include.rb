require 'chunks/wiki'

# Includes the contents of another page for rendering.
# The include command looks like this: "[[!include PageName]]".
# It is a WikiReference since it refers to another page (PageName)
# and the wiki content using this command must be notified
# of changes to that page.
# If the included page could not be found, a warning is displayed.

class Include < WikiChunk::WikiReference

  INCLUDE_PATTERN = /\[\[!include\s+([^\]\s][^\]]*?)\s*\]\]/i
  def self.pattern() INCLUDE_PATTERN end

  def initialize(match_data, content)
    super
    @page_name = match_data[1].strip
    rendering_mode = content.options[:mode] || :show
    add_to_include_list
    @unmask_text = get_unmask_text_avoiding_recursion_loops(rendering_mode)
  end

  private
  
  def get_unmask_text_avoiding_recursion_loops(rendering_mode)
    if refpage
      return "<em>Recursive include detected: #{@content.page_name} " +
          "&#x2192; #{@content.page_name}</em>\n" if self_inclusion(refpage)
      renderer = PageRenderer.new(refpage.current_revision)
      included_content =
        case rendering_mode
          when :show then renderer.display_content
          when :publish then renderer.display_published
          when :export then renderer.display_content_for_export
          when :s5 then renderer.display_s5
        else
          raise "Unsupported rendering mode #{@mode.inspect}"
        end
      @content.merge_chunks(included_content)
      clear_include_list
      return included_content.pre_rendered
    else
      clear_include_list
      return "<em>Could not include #{@page_name}</em>\n"
    end
  end
  
  # We track included pages in a thread-local variable.
  # This allows a multi-threaded Rails to handle multiple
  #   simultaneous requests (one request/thread), without
  #   getting confused.
  
  def add_to_include_list
    Thread.current[:chunk_included_by] ?
      Thread.current[:chunk_included_by].push(@content.page_name) :
      Thread.current[:chunk_included_by] = [@content.page_name]
  end

  def clear_include_list
    Thread.current[:chunk_included_by] = []  
  end
    
  def self_inclusion(refpage)
    if Thread.current[:chunk_included_by].include?(refpage.page.name)
      @content.delete_chunk(self)
      clear_include_list
    else
      return false
    end
  end

end
