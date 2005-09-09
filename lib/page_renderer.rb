# Temporary class containing all rendering stuff from a Revision 
# I want to shift all rendering loguc to the controller eventually

class PageRenderer

  def initialize(revision)
    @revision = revision
  end

  # Returns an array of all the WikiIncludes present in the content of this revision.
  def wiki_includes
    unless @wiki_includes_cache 
      chunks = display_content.find_chunks(Include)
      @wiki_includes_cache = chunks.map { |c| ( c.escaped? ? nil : c.page_name ) }.compact.uniq
    end
    @wiki_includes_cache
  end

  # Returns an array of all the WikiReferences present in the content of this revision.
  def wiki_references
    unless @wiki_references_cache 
      chunks = display_content.find_chunks(WikiChunk::WikiReference)
      @wiki_references_cache = chunks.map { |c| ( c.escaped? ? nil : c.page_name ) }.compact.uniq
    end
    @wiki_references_cache
  end  

  # Returns an array of all the WikiWords present in the content of this revision.
  def wiki_words
    unless @wiki_words_cache
      wiki_chunks = display_content.find_chunks(WikiChunk::WikiLink)
      @wiki_words_cache = wiki_chunks.map { |c| ( c.escaped? ? nil : c.page_name ) }.compact.uniq
    end
    @wiki_words_cache
  end

  # Returns an array of all the WikiWords present in the content of this revision.
  # that already exists as a page in the web.
  def existing_pages
    wiki_words.select { |wiki_word| @revision.page.web.page(wiki_word) }
  end

  # Returns an array of all the WikiWords present in the content of this revision
  # that *doesn't* already exists as a page in the web.
  def unexisting_pages
    wiki_words - existing_pages
  end  

  # Explicit check for new type of display cache with chunks_by_type method.
  # Ensures new version works with older snapshots.
  def display_content
    unless @display_cache && @display_cache.respond_to?(:chunks_by_type)
      @display_cache = WikiContent.new(@revision)
      @display_cache.render!
    end
    @display_cache
  end

  # TODO this probably doesn't belong in revision (because it has to call back the page)
  def display_diff
    previous_revision = @revision.page.previous_revision(@revision)
    if previous_revision 
      HTMLDiff.diff(PageRenderer.new(previous_revision).display_content, display_content) 
    else 
      display_content
    end
  end

  def clear_display_cache
    @wiki_words_cache = @published_cache = @display_cache = @wiki_includes_cache = 
      @wiki_references_cache = nil
  end

  def display_published
    unless @published_cache && @published_cache.respond_to?(:chunks_by_type)
      @published_cache = WikiContent.new(@revision, {:mode => :publish})
      @published_cache.render!
    end
    @published_cache
  end

  def display_content_for_export
    WikiContent.new(@revision, {:mode => :export} ).render!
  end
  
  def force_rendering
    begin
      display_content.render!
    rescue => e
      logger.error "Failed rendering page #{@name}"
      logger.error e
      message = e.message
      # substitute content with an error message
      @revision.content = <<-EOL
          <p>Markup engine has failed to render this page, raising the following error:</p>
          <p>#{message}</p>
          <pre>#{self.content}</pre>
      EOL
      clear_display_cache
      raise e
    end
  end

  protected

end