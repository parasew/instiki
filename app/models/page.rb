require "date"
require "page_lock"
require "revision"
require "wiki_words"
require "chunks/wiki"

class Page
  include PageLock

  CONTINOUS_REVISION_PERIOD = 30 * 60 # 30 minutes

  attr_reader :name, :revisions, :web
  
  def initialize(web, name, content, created_at, author)
    @web, @name, @revisions = web, name, []
    revise(content, created_at, author)
  end

  def revise(content, created_at, author)
    if !@revisions.empty? && continous_revision?(created_at, author)
      @revisions.last.created_at = Time.now
      @revisions.last.content    = content
      @revisions.last.clear_display_cache
    else
      @revisions << Revision.new(self, @revisions.length, content, created_at, author)
    end
    
    web.refresh_pages_with_references(name) if @revisions.length == 1
  end
  
  def rollback(revision_number, created_at, author_ip = nil)
    roll_back_revision = @revisions[revision_number].dup
    revise(roll_back_revision.content, created_at, Author.new(roll_back_revision.author, author_ip))
  end
  
  def revisions?
    revisions.length > 1
  end
  
  def revised_on
    created_on
  end
  
  def pretty_revised_on
    DateTime.new(revised_on.year, revised_on.mon, revised_on.day).strftime "%B %e, %Y" 
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

  # Returns the original wiki-word name as separate words, so "MyPage" becomes "My Page".
  def plain_name
    WikiWords.separate(name, web.brackets_only)
  end

  def link(options = {})
    web.make_link(name, nil, options)
  end
  
  def author_link(options = {})
    web.make_link(author, nil, options)
  end
  
  private
    def continous_revision?(created_at, author)
      @revisions.last.author == author && @revisions.last.created_at + CONTINOUS_REVISION_PERIOD > created_at
    end
  
    # Forward method calls to the current revision, so the page responds to all revision calls
    def method_missing(method_symbol)
      revisions.last.send(method_symbol)
    end
end