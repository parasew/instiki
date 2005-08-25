require 'cgi'
require 'page'
require 'page_set'
require 'wiki_words'
require 'zip/zip'

class Web
  attr_accessor :name, :password, :safe_mode, :pages
  attr_accessor :additional_style, :allow_uploads, :published
  attr_reader :address

  # there are getters for all these attributes, too
  attr_writer :markup, :color, :brackets_only, :count_pages, :max_upload_size

  def initialize(parent_wiki, name, address, password = nil)
    self.address = address
    @wiki, @name, @password = parent_wiki, name, password

    set_compatible_defaults

    @pages = {}
    @allow_uploads = true
    @additional_style = nil
    @published = false
    @count_pages = false
  end

  # Explicitly sets value of some web attributes to defaults, unless they are already set
  def set_compatible_defaults
    @markup = markup()
    @color = color()
    @safe_mode = safe_mode()
    @brackets_only = brackets_only()
    @max_upload_size = max_upload_size()
    @wiki = wiki
  end
  
  # All below getters know their default values. This is necessary to ensure compatibility with 
  # 0.9 storages, where they were not defined.
  def brackets_only() @brackets_only || false end
  def color() @color ||= '008B26' end
  def count_pages()   @count_pages || false end
  def markup() @markup ||= :textile end
  def max_upload_size() @max_upload_size || 100; end
  def wiki() @wiki ||= WikiService.instance; end

   def add_page(name, content, created_at, author)
     page = Page.new(self, name)
     page.revise(content, created_at, author)
     @pages[page.name] = page
   end
  
  def address=(the_address)
    if the_address != CGI.escape(the_address)
      raise Instiki::ValidationError.new('Web name should contain only valid URI characters') 
    end
    @address = the_address
  end

  def authors
    select.authors 
  end

  def categories
    select.map { |page| page.categories }.flatten.uniq.sort
  end

  def has_page?(name)
    pages[name]
  end

  def has_file?(name)
    wiki.file_yard(self).has_file?(name)
  end

  # Create a link for the given page name and link text based
  # on the render mode in options and whether the page exists
  # in the this web.
  # The links a relative, and will work only if displayed on another WikiPage.
  # It should not be used in menus, templates and such - instead, use link_to_page helper
  def make_link(name, text = nil, options = {})
    text = CGI.escapeHTML(text || WikiWords.separate(name))
    mode = options[:mode] || :show
    base_url = options[:base_url] || '..'
    link_type = options[:link_type] || :show
    case link_type.to_sym
    when :show
      UrlGenerator.new.make_page_link(mode, name, text, base_url, has_page?(name))
    when :file
      UrlGenerator.new.make_file_link(mode, name, text, base_url, has_file?(name))
    when :pic
      UrlGenerator.new.make_pic_link(mode, name, text, base_url, has_file?(name))
    else
      raise "Unknown link type: #{link_type}"
    end
  end

  # Clears the display cache for all the pages with references to 
  def refresh_pages_with_references(page_name)
    select.pages_that_reference(page_name).each { |page| 
      page.revisions.each { |revision| revision.clear_display_cache }
    }
  end
  
  def refresh_revisions
    select.each { |page| page.revisions.each { |revision| revision.clear_display_cache } }
  end

  def remove_pages(pages_to_be_removed)
    pages.delete_if { |page_name, page| pages_to_be_removed.include?(page) }
  end
  
  def revised_on
    select.most_recent_revision
  end
    
  def select(&condition)
    PageSet.new(self, @pages.values, condition)
  end
  
  private

    # Returns an array of all the wiki words in any current revision
    def wiki_words
      pages.values.inject([]) { |wiki_words, page| wiki_words << page.wiki_words }.flatten.uniq
    end
    
    # Returns an array of all the page names on this web
    def page_names
      pages.keys
    end
    
end
