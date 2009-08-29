class Web < ActiveRecord::Base
  ## Associations

  has_many :pages,      :dependent => :destroy
  has_many :wiki_files, :dependent => :destroy

  has_many :revisions,  :through => :pages

  ## Hooks

  before_save :sanitize_markup
  after_save :create_files_directory

  before_validation :validate_address

  ## Validations

  validates_uniqueness_of :address

  validates_length_of :color, :in => 3..6

  ## Methods

  def wiki
    Wiki.new
  end

  def settings_changed?(markup, safe_mode, brackets_only)
    self.markup != markup || 
    self.safe_mode != safe_mode || 
    self.brackets_only != brackets_only
  end

  def add_page(name, content, time, author, renderer)
    page = page(name) || Page.new(:web => self, :name => name)
    page.revise(content, name, time, author, renderer)
  end

  # @return [Array<String>] a collection of all the names of the authors that 
  #   have ever contributed to the pages for this Web
  def authors
    revisions.all(
      :select => "DISTINCT revisions.author",
      :order  => "1"
    ).collect(&:author)
  end

  def categories
    select.map { |page| page.categories }.flatten.uniq.sort
  end

  # @param [String] name the name of some associated Page record to find
  # @return [Page, nil] the associated Page record, or +nil+ if no record is 
  #   found with the provided name
  def page(name)
    pages.find_by_name(name)
  end

  # @return [Page] the last associated Page record
  def last_page
    pages.last
  end

  # @param [String] name the name of some potential Page record
  # @return [Boolean] whether or not a given Page record exists with a given 
  #   name
  def has_page?(name)
    pages.exists?(:name => name)
  end

  def has_redirect_for?(name)
     WikiReference.page_that_redirects_for(self, name) 
  end

  def page_that_redirects_for(name)
     page(WikiReference.page_that_redirects_for(self, name))
  end

  def has_file?(file_name)
    WikiFile.find_by_file_name(file_name) != nil
  end

  def file_list(sort_order = 'file_name')
    WikiFile.all(:order => sort_order, :conditions => ['web_id = ?', id])
  end

  def pages_that_link_to(page_name)
    WikiReference.pages_that_link_to(self, page_name)
  end

  def pages_that_link_to_file(file_name)
    WikiReference.pages_that_link_to_file(self, file_name)
  end

  def description(file_name)
    file = WikiFile.find_by_file_name(file_name)
    file.description if file
  end

  # @return [Symbol] the type of markup used by this Web
  def markup
    self[:markup].to_sym
  end

  # @return [Hash] a Hash wherein the key is some author's name, and the 
  #   values are an array of page names for that author.
  def page_names_by_author
    data = revisions.all(
      :select => "DISTINCT revisions.author AS author, pages.name AS page_name",
      :order  => "pages.name"
    )

    data.inject({}) do |result, revision|
      result[revision.author] ||= []
      result[revision.author] <<  revision.page_name
      result
    end
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

  def create_files_directory
    return unless allow_uploads == 1
    dummy_file = self.wiki_files.build(:file_name => '0', :description => '0', :content => '0')
    File.umask(0002)
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

  def files_path
    path = Rails.root.join("webs")
    if default_web?
      path.join("files")
    else
      path.join(address, "files")
    end
  end

  def blahtex_pngs_path
    files_path.join("pngs")
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

    def sanitize_markup
      self.markup = markup.to_s
    end

    def validate_address
      unless address == CGI.escape(address)
        self.errors.add(:address, 'should contain only valid URI characters')
        raise Instiki::ValidationError.new("#{self.class.human_attribute_name('address')} #{errors.on(:address)}")
      end
    end

    def default_web?
      defined? DEFAULT_WEB and self.address == DEFAULT_WEB
    end
end
