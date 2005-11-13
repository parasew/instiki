class Web < ActiveRecord::Base
  has_many :pages
  has_many :wiki_files

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
    connection.select_all(
        'SELECT DISTINCT r.author AS author ' + 
        'FROM revisions r ' +
        'JOIN pages p ON p.id = r.page_id ' +
        'ORDER by 1').collect { |row| row['author'] }
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

  def has_file?(file_name)
    WikiFile.find_by_file_name(file_name) != nil
  end

  def markup
    read_attribute('markup').to_sym
  end

  def page_names_by_author
    connection.select_all(
        'SELECT DISTINCT r.author AS author, p.name AS page_name ' +
        'FROM revisions r ' +
        'JOIN pages p ON r.page_id = p.id ' +
        "WHERE p.web_id = #{self.id} " +
        'ORDER by p.name'
    ).inject({}) { |result, row|
        author, page_name = row['author'], row['page_name']
        result[author] = [] unless result.has_key?(author)
        result[author] << page_name
        result
    }
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
  
  def to_param
    address
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
    after_save :create_files_directory
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
    
    def create_files_directory
      return unless allow_uploads == 1
      dummy_file = self.wiki_files.build(:file_name => '0', :description => '0', :content => '0')
      dir = File.dirname(dummy_file.content_path)
      begin
        require 'fileutils'
        FileUtils.mkdir_p dir
        dummy_file.save
        dummy_file.destroy
      rescue => e
        logger.error("Failed create files directory for #{self.address}: #{e}")
        raise "Instiki could not create directory to store uploaded files. " +
              "Please make sure that Instiki is allowed to create directory " +
              "#{File.expand_path(dir)} and add files to it."
      end
    end
    
    def default_web?
      defined? DEFAULT_WEB and self.address == DEFAULT_WEB
    end
    
    def files_path
      if default_web?
        "#{RAILS_ROOT}/public/#{self.address}/files"
      else
        "#{RAILS_ROOT}/public/files"
      end
    end
end
