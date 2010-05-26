require 'xhtmldiff'

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

      previous_content = "<div>" + WikiContent.new(previous_revision, @@url_generator).render!.to_s + "</div>"
      current_content = "<div>" + display_content.to_s  + "</div>"
      diff_doc = REXML::Document.new
      div = REXML::Element.new('div', nil, {:respect_whitespace =>:all})
      div.attributes['class'] = 'xhtmldiff_wrapper'
      diff_doc << div
      hd = XHTMLDiff.new(div)

      parsed_previous_revision = REXML::HashableElementDelegator.new(
           REXML::XPath.first(REXML::Document.new(previous_content), '/div'))
      parsed_display_content = REXML::HashableElementDelegator.new(
           REXML::XPath.first(REXML::Document.new(current_content), '/div'))
      Diff::LCS.traverse_balanced(parsed_previous_revision, parsed_display_content, hd)

      diffs = ''
      diff_doc.write(diffs, -1, true, true)
      diffs.gsub(/\A<div class='xhtmldiff_wrapper'>(.*)<\/div>\Z/m, '\1').html_safe
    else
      display_content
    end
  end

  attr :s5_theme
  def s5_theme=(s)
    @s5_theme = s
  end

  # Renders an S5 slideshow
  def display_s5
    @display_s5 ||= render(:mode => :s5,
                           :engine_opts => {:author => @author, :title => @plain_name},
                           :renderer => self)
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
    @wiki_words_cache ||= find_wiki_words(display_content) 
  end
  
  def find_wiki_words(rendering_result)
    the_wiki_words = wiki_links(rendering_result)
    # Exclude backslash-escaped wiki words, such as \WikiWord, as well as links to files 
    # and pictures, such as [[foo.txt:file]] or [[foo.jpg:pic]]
    the_wiki_words.delete_if { |link| link.escaped? or [:pic, :file, :audio, :video, :delete].include?(link.link_type) }
    # convert to the list of unique page names
    the_wiki_words.map { |link| ( link.page_name ) }.uniq
  end

  # Returns an array of all the WikiWords present in the content of this revision.
  def wiki_files
    @wiki_files_cache ||= find_wiki_files(display_content) 
  end
    
  def find_wiki_files(rendering_result)
     the_wiki_files = wiki_links(rendering_result)
     the_wiki_files.delete_if { |link| ![:pic, :file, :audio, :video].include?(link.link_type) }
     the_wiki_files.map { |link| ( link.page_name ) }.uniq
  end
  
  def wiki_links(rendering_result)
     rendering_result.find_chunks(WikiChunk::WikiLink)
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
    update_references(rendering_result) if options[:update_references]
    rendering_result
  end
  
  def update_references(rendering_result)
    WikiReference.delete_all ['page_id = ?', @revision.page_id]

    references = @revision.page.wiki_references

    wiki_words = find_wiki_words(rendering_result)
    # TODO it may be desirable to save links to files and pictures as WikiReference objects
    # present version doesn't do it
    
    wiki_words.each do |referenced_name|
      # Links to self are always considered linked
      if referenced_name == @revision.page.name
        link_type = WikiReference::LINKED_PAGE
      else
        link_type = WikiReference.link_type(@revision.page.web, referenced_name)
      end
      references.build :referenced_name => referenced_name, :link_type => link_type
    end
    
    wiki_files = find_wiki_files(rendering_result)
    wiki_files.each do |referenced_name|
      references.build :referenced_name => referenced_name, :link_type => WikiReference::FILE
    end
    
    include_chunks = rendering_result.find_chunks(Include)
    includes = include_chunks.map { |c| ( c.escaped? ? nil : c.page_name ) }.compact.uniq
    includes.each do |included_page_name|
      references.build :referenced_name => included_page_name, 
          :link_type => WikiReference::INCLUDED_PAGE
    end
    
    redirect_chunks = rendering_result.find_chunks(Redirect)
    redirects = redirect_chunks.map { |c| ( c.escaped? ? nil : c.page_name ) }.compact.uniq
    redirects.each do |redirected_page_name|
      references.build :referenced_name => redirected_page_name, 
          :link_type => WikiReference::REDIRECTED_PAGE
    end
    
    # ugly hack: store these in a thread-local variable, so that the cache-sweeper has access to it.
    Thread.current[:page_redirects] ?
      Thread.current[:page_redirects].update({ @revision.page => redirects}) :
      Thread.current[:page_redirects] = { @revision.page => redirects}
    
    categories = rendering_result.find_chunks(Category).map { |cat| cat.list }.flatten
    categories.each do |category|
      references.build :referenced_name => category, :link_type => WikiReference::CATEGORY
    end
  end
end
