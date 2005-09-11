class Web < ActiveRecord::Base
  has_many :pages

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
  
  def add_page(name, content, time, author, renderer)
    page = page(name) || Page.new(:web => self, :name => name)
    page.revise(content, time, author, renderer)
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

  def remove_pages(pages_to_be_removed)
    pages_to_be_removed.each { |p| p.destroy }
  end
  
  def revised_at
    select.most_recent_revision
  end
    
  def select(&condition)
    PageSet.new(self, pages, condition)
  end
  
  def select_all
    PageSet.new(self, pages, nil)
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
