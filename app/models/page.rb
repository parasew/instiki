class Page < ActiveRecord::Base
  belongs_to :web
  has_many :revisions, :order => 'number'
  has_one :current_revision, :class_name => 'Revision', :order => 'number DESC'
    
  def revise(content, created_at, author)
    revisions_size = new_record? ? 0 : revisions.size
    if (revisions_size > 0) and content == current_revision.content
      raise Instiki::ValidationError.new(
          "You have tried to save page '#{name}' without changing its content")
    end
    
    author = Author.new(author.to_s) unless author.is_a?(Author)

    # Try to render content to make sure that markup engine can take it,
    # before addin a revision to the page
    Revision.new(:page => self, :content => content, :created_at => created_at, :author => author).force_rendering

    # A user may change a page, look at it and make some more changes - several times.
    # Not to record every such iteration as a new revision, if the previous revision was done 
    # by the same author, not more than 30 minutes ago, then update the last revision instead of
    # creating a new one
    if (revisions_size > 0) && continous_revision?(created_at, author)
      current_revision.update_attributes(:created_at => created_at, :content => content)
    else
      Revision.create(:page => self, :content => content, :created_at => created_at, :author => author)
    end
    
    self.created_at = created_at
    save
    web.refresh_pages_with_references(name) if revisions_size == 0
    
    self
  end

  def rollback(revision_number, created_at, author_ip = nil)
    roll_back_revision = Revision.find(:first, :conditions => ['page_id = ? AND number = ?', id, revision_number])
    revise(roll_back_revision.content, created_at, Author.new(roll_back_revision.author, author_ip))
  end
  
  def revisions?
    revisions.size > 1
  end

  def revised_on
    created_on
  end

  def in_category?(cat)
    cat.nil? || cat.empty? || categories.include?(cat)
  end

  def categories
    display_content.find_chunks(Category).map { |cat| cat.list }.flatten
  end

  def authors
    revisions.collect { |rev| rev.author }
  end

  def references
    web.select.pages_that_reference(name)
  end

  def linked_from
    web.select.pages_that_link_to(name)
  end

  def included_from
    web.select.pages_that_include(name)
  end

  # Returns the original wiki-word name as separate words, so "MyPage" becomes "My Page".
  def plain_name
    web.brackets_only? ? name : WikiWords.separate(name)
  end

  # used to build chunk ids. 
  #def id
  #  @id ||= name.unpack('H*').first
  #end

  def link(options = {})
    web.make_link(name, nil, options)
  end

  def author_link(options = {})
    web.make_link(author, nil, options)
  end

  LOCKING_PERIOD = 30.minutes

  def lock(time, locked_by)
    update_attributes(:locked_at => time, :locked_by => locked_by)
  end
  
  def lock_duration(time)
    ((time - locked_at) / 60).to_i unless locked_at.nil?
  end
  
  def unlock
    update_attribute(:locked_at, nil)
  end
  
  def locked?(comparison_time)
    locked_at + LOCKING_PERIOD > comparison_time unless locked_at.nil?
  end

  private

    def continous_revision?(created_at, author)
      current_revision.author == author && current_revision.created_at + 30.minutes > created_at
    end

    # Forward method calls to the current revision, so the page responds to all revision calls
    def method_missing(method_id, *args, &block)
      method_name = method_id.to_s
      # Perform a hand-off to AR::Base#method_missing
      if @attributes.include?(method_name) or md = /(=|\?|_before_type_cast)$/.match(method_name)
        super(method_id, *args, &block)
      else
        current_revision.send(method_id)
      end
    end
end
