require "cgi"
require "page"
require "page_set"
require "wiki_words"
require "zip/zip"

class Web
  attr_accessor :name, :address, :password, :markup, :color, :safe_mode, :pages
  attr_accessor :additional_style, :published, :brackets_only, :count_pages
  
  def initialize(name, address, password = nil)
    @name, @address, @password, @safe_mode = name, address, password, false
    @pages = {}

    # assign default values
    @color = '008B26'
    @markup = :textile 
  end

  def add_page(page)
    @pages[page.name] = page
  end

  def remove_pages(pages_to_be_removed)
    pages.delete_if { |page_name, page| pages_to_be_removed.include?(page) }
  end
  
  def select(&condition)
    PageSet.new(self, @pages.values, condition)
  end
  
  def revised_on
    select.most_recent_revision
  end
    
  def authors 
    select.authors 
  end

  def categories
    select.map { |page| page.categories }.flatten.uniq.sort
  end

  # Create a link for the given page name and link text based
  # on the render mode in options and whether the page exists
  # in the this web.
  def make_link(name, text = nil, options = {})
    page = pages[name]
    text = text || WikiWords.separate(name)
    link = CGI.escape(name)
    
    case options[:mode]
      when :export
        if page then "<a class=\"existingWikiWord\" href=\"#{link}.html\">#{text}</a>"
        else "<span class=\"newWikiWord\">#{text}</span>" end
      when :publish
        if page then "<a class=\"existingWikiWord\" href=\"../published/#{link}\">#{text}</a>"
        else "<span class=\"newWikiWord\">#{text}</span>" end
      else
        if page then "<a class=\"existingWikiWord\" href=\"../show/#{link}\">#{text}</a>"
        else "<span class=\"newWikiWord\">#{text}<a href=\"../show/#{link}\">?</a></span>" end
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