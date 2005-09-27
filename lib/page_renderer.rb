require 'diff'
# Temporary class containing all rendering stuff from a Revision 
# I want to shift all rendering loguc to the controller eventually

class PageRenderer

  def self.setup_url_generator(url_generator)
    @@url_generator = url_generator
  end

  def self.teardown_url_generator
    @@url_generator = nil
  end

  attr_reader :revision

  def initialize(revision = nil)
    self.revision = revision
  end

  def revision=(r)
    @revision = r
    @display_content = @display_published = @wiki_words_cache = @wiki_includes_cache = 
        @wiki_references_cache = nil
  end

  def display_content(update_references = false)
    @display_content ||= render(:update_references => update_references)
  end

  def display_content_for_export
    render :mode => :export
  end

  def display_published
    @display_published ||= render(:mode => :publish)
  end

  def display_diff
    previous_revision = @revision.page.previous_revision(@revision)
    if previous_revision
      rendered_previous_revision = WikiContent.new(previous_revision, @@url_generator).render!
      HTMLDiff.diff(rendered_previous_revision, display_content) 
    else
      display_content
    end
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

  private
  
  def render(options = {})

    rendering_result = WikiContent.new(@revision, @@url_generator, options).render!
    
    if options[:update_references]
      update_references(rendering_result)
    end
    rendering_result
  end
  
  def update_references(rendering_result)
    WikiReference.delete_all ['page_id = ?', @revision.page_id]

    references = @revision.page.wiki_references
        
    wiki_word_chunks = rendering_result.find_chunks(WikiChunk::WikiLink)
    wiki_words = wiki_word_chunks.map { |c| ( c.escaped? ? nil : c.page_name ) }.compact.uniq
    
    wiki_words.each do |referenced_name|
      # Links to self are always considered linked
      if referenced_name == @revision.page.name
        link_type = WikiReference::LINKED_PAGE
      else
        link_type = WikiReference.link_type(@revision.page.web, referenced_name)
      end
      references.create :referenced_name => referenced_name, :link_type => link_type
    end
    
    include_chunks = rendering_result.find_chunks(Include)
    includes = include_chunks.map { |c| ( c.escaped? ? nil : c.page_name ) }.compact.uniq
    includes.each do |included_page_name|
      references.create :referenced_name => included_page_name, 
          :link_type => WikiReference::INCLUDED_PAGE
    end
    
    categories = rendering_result.find_chunks(Category).map { |cat| cat.list }.flatten
    categories.each do |category|
      references.create :referenced_name => category, :link_type => WikiReference::CATEGORY
    end
  end
end
