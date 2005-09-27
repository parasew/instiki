class Page < ActiveRecord::Base
  belongs_to :web
  has_many :revisions, :order => 'id'
  has_many :wiki_references, :order => 'referenced_name'
  has_one :current_revision, :class_name => 'Revision', :order => 'id DESC'

  def revise(content, time, author, renderer)
    revisions_size = new_record? ? 0 : revisions.size
    if (revisions_size > 0) and content == current_revision.content
      raise Instiki::ValidationError.new(
          "You have tried to save page '#{name}' without changing its content")
    end
    
    author = Author.new(author.to_s) unless author.is_a?(Author)

    # Try to render content to make sure that markup engine can take it,
    renderer.revision = Revision.new(
       :page => self, :content => content, :author => author, :revised_at => time)
    renderer.display_content(update_references = true)

    # A user may change a page, look at it and make some more changes - several times.
    # Not to record every such iteration as a new revision, if the previous revision was done 
    # by the same author, not more than 30 minutes ago, then update the last revision instead of
    # creating a new one
    if (revisions_size > 0) && continous_revision?(time, author)
      current_revision.update_attributes(:content => content, :revised_at => time)
    else
      revisions.create(:content => content, :author => author, :revised_at => time)
    end
    save
    self
  end

  def rollback(revision_number, time, author_ip, renderer)
    roll_back_revision = self.revisions[revision_number]
    if roll_back_revision.nil?
      raise Instiki::ValidationError.new("Revision #{revision_number} not found")
    end
    author = Author.new(roll_back_revision.author.name, author_ip)
    revise(roll_back_revision.content, time, author, renderer)
  end

  def revisions?
    revisions.size > 1
  end

  def previous_revision(revision)
    revision_index = revisions.each_with_index do |rev, index| 
      if rev.id == revision.id 
        break index 
      else
        nil
      end
    end
    if revision_index.nil? or revision_index == 0
      nil
    else
      revisions[revision_index - 1]
    end
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

    def continous_revision?(time, author)
      (current_revision.author == author) && (revised_at + 30.minutes > time)
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
