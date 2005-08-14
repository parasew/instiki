require 'cgi'

class Web < ActiveRecord::Base
  has_many :pages#, :include => [:current_revision, :web]

  def wiki
    Wiki.new
  end
  
  def file_yard
    @file_yard ||= FileYard.new("#{Wiki.storage_path}/#{address}", max_upload_size)
  end
  
  def settings_changed?(markup, safe_mode, brackets_only)
    self.markup != markup || 
    self.safe_mode != safe_mode || 
    self.brackets_only != brackets_only
  end
  
  def add_page(name, content, time, author)
    page = page(name) || Page.new(:web => self, :name => name)
    page.revise(content, time, author)
  end
  
  def authors
    select.authors 
  end

  def categories
    select.map { |page| page.categories }.flatten.uniq.sort
  end

  def page(name)
    pages.find(:first, :conditions => ['name = ?', name])
  end

  def has_page?(name)
    Page.count(['web_id = ? AND name = ?', id, name]) > 0
  end

  def has_file?(name)
    wiki.file_yard(self).has_file?(name)
  end

  def markup
    read_attribute('markup').to_sym
  end

  def make_file_link(mode, name, text, base_url)
    link = CGI.escape(name)
    case mode
    when :export
      if has_file?(name) then "<a class=\"existingWikiWord\" href=\"#{link}.html\">#{text}</a>"
      else "<span class=\"newWikiWord\">#{text}</span>" end
    when :publish
      if has_file?(name) then "<a class=\"existingWikiWord\" href=\"#{base_url}/published/#{link}\">#{text}</a>"
      else "<span class=\"newWikiWord\">#{text}</span>" end
    else 
      if has_file?(name)
        "<a class=\"existingWikiWord\" href=\"#{base_url}/file/#{link}\">#{text}</a>"
      else 
        "<span class=\"newWikiWord\">#{text}<a href=\"#{base_url}/file/#{link}\">?</a></span>"
      end
    end
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
      make_page_link(mode, name, text, base_url)
    when :file
      make_file_link(mode, name, text, base_url)
    when :pic
      make_pic_link(mode, name, text, base_url)
    else
      raise "Unknown link type: #{link_type}"
    end
  end

  def make_page_link(mode, name, text, base_url)
    link = CGI.escape(name)
    case mode.to_sym
    when :export
      if has_page?(name) then %{<a class="existingWikiWord" href="#{link}.html">#{text}</a>}
      else %{<span class="newWikiWord">#{text}</span>} end
    when :publish
      if has_page?(name) then %{<a class="existingWikiWord" href="#{base_url}/published/#{link}">#{text}</a>}
      else %{<span class="newWikiWord">#{text}</span>} end
    else 
      if has_page?(name)
        %{<a class="existingWikiWord" href="#{base_url}/show/#{link}">#{text}</a>}
      else 
        %{<span class="newWikiWord">#{text}<a href="#{base_url}/show/#{link}">?</a></span>}
      end
    end
  end

  def make_pic_link(mode, name, text, base_url)
    link = CGI.escape(name)
    case mode.to_sym
    when :export
      if has_file?(name) then %{<img alt="#{text}" src="#{link}" />}
      else %{<img alt="#{text}" src="no image" />} end
    when :publish
      if has_file?(name) then %{<img alt="#{text}" src="#{link}" />}
      else %{<span class="newWikiWord">#{text}</span>} end
    else 
      if has_file?(name) then %{<img alt="#{text}" src="#{base_url}/pic/#{link}" />}
      else %{<span class="newWikiWord">#{text}<a href="#{base_url}/pic/#{link}">?</a></span>} end
    end
  end

  # Clears the display cache for all the pages with references to 
  def refresh_pages_with_references(page_name)
    #select.pages_that_reference(page_name).each { |page| 
    #  page.revisions.each { |revision| revision.clear_display_cache }
    #}
  end
  
  def refresh_revisions
    select.each { |page| page.revisions.each { |revision| revision.clear_display_cache } }
  end

  def remove_pages(pages_to_be_removed)
    pages_to_be_removed.each { |p| p.destroy }
  end
  
  def revised_on
    select.most_recent_revision
  end
    
  def select(&condition)
    PageSet.new(self, pages, condition)
  end
  
  private

    # Returns an array of all the wiki words in any current revision
    def wiki_words
      pages.inject([]) { |wiki_words, page| wiki_words << page.wiki_words }.flatten.uniq
    end
    
    # Returns an array of all the page names on this web
    def page_names
      pages.map { |p| p.name }
    end
    
  protected
    before_save :sanitize_markup
    before_validation :validate_address
    validates_uniqueness_of :address
    validates_length_of :color, :in => 3..6
  
    def sanitize_markup
      self.markup = markup.to_s
    end
    
    def validate_address
      unless address == CGI.escape(address)
        self.errors.add(:address, 'should contain only valid URI characters')
        raise Instiki::ValidationError.new("#{self.class.human_attribute_name('address')} #{errors.on(:address)}")
      end
    end
end
