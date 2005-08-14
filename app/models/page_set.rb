# Container for a set of pages with methods for manipulation.

class PageSet < Array
  attr_reader :web

  def initialize(web, pages = nil, condition = nil)
    @web = web
    # if pages is not specified, make a list of all pages in the web
    if pages.nil?
      super(web.pages)
    # otherwise use specified pages and condition to produce a set of pages
    elsif condition.nil?
      super(pages)
    else
      super(pages.select { |page| condition[page] })
    end
  end

  def most_recent_revision
    self.map { |page| page.revised_at }.max || Time.at(0)
  end

  def by_name
    PageSet.new(@web, sort_by { |page| page.name })
  end

  alias :sort :by_name

  def by_revision
    PageSet.new(@web, sort_by { |page| page.revised_at }).reverse 
  end
  
  def pages_that_reference(page_name)
    self.select { |page| page.wiki_references.include?(page_name) }
  end
  
  def pages_that_link_to(page_name)
    self.select { |page| page.wiki_words.include?(page_name) }
  end

  def pages_that_include(page_name)
    self.select { |page| page.wiki_includes.include?(page_name) }
  end

  def pages_authored_by(author)
    self.select { |page| page.authors.include?(author) }
  end

  def characters
    self.inject(0) { |chars,page| chars += page.content.size }
  end

  # Returns all the orphaned pages in this page set. That is,
  # pages in this set for which there is no reference in the web.
  # The HomePage and author pages are always assumed to have
  # references and so cannot be orphans
  # Pages that refer to themselves and have no links from outside are oprphans.
  def orphaned_pages
    never_orphans = web.select.authors + ['HomePage']
    self.select { |page|
      if never_orphans.include? page.name
        false
      else
        references = pages_that_reference(page.name)
        references.empty? or references == [page]
      end
    }
  end

  # Returns all the wiki words in this page set for which
  # there are no pages in this page set's web
  def wanted_pages
    wiki_words - web.select.names
  end

  def names
    self.map { |page| page.name }
  end

  def wiki_words
    self.inject([]) { |wiki_words, page| wiki_words << page.wiki_words }.flatten.uniq
  end

  def authors
    self.inject([]) { |authors, page| authors << page.authors }.flatten.uniq.sort
  end

end
