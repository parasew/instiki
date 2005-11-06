class WikiReference < ActiveRecord::Base

  LINKED_PAGE = 'L'
  WANTED_PAGE = 'W'
  INCLUDED_PAGE = 'I'
  CATEGORY = 'C'
  AUTHOR = 'A'

  belongs_to :page
  validates_inclusion_of :link_type, :in => [LINKED_PAGE, WANTED_PAGE, INCLUDED_PAGE, CATEGORY, AUTHOR]

  # FIXME all finders below MUST restrict their results to pages belonging to a particular web

  def self.link_type(web, page_name)
    web.has_page?(page_name) ? LINKED_PAGE : WANTED_PAGE
  end

  def self.pages_that_reference(page_name)
    query = 'SELECT name FROM pages JOIN wiki_references ON pages.id = wiki_references.page_id ' +
        'WHERE wiki_references.referenced_name = ?' +
        "AND wiki_references.link_type in ('#{LINKED_PAGE}', '#{WANTED_PAGE}', '#{INCLUDED_PAGE}')"
    names = connection.select_all(sanitize_sql([query, page_name])).map { |row| row['name'] }
  end

  def self.pages_that_link_to(page_name)
    query = 'SELECT name FROM pages JOIN wiki_references ON pages.id = wiki_references.page_id ' +
        'WHERE wiki_references.referenced_name = ? ' +
        "AND wiki_references.link_type in ('#{LINKED_PAGE}', '#{WANTED_PAGE}')"
    names = connection.select_all(sanitize_sql([query, page_name])).map { |row| row['name'] }
  end

  def self.pages_that_include(page_name)
    query = 'SELECT name FROM pages JOIN wiki_references ON pages.id = wiki_references.page_id ' +
        'WHERE wiki_references.referenced_name = ? ' +
        "AND wiki_references.link_type = '#{INCLUDED_PAGE}'"
    names = connection.select_all(sanitize_sql([query, page_name])).map { |row| row['name'] }
  end

  def self.pages_in_category(category)
    query = 'SELECT name FROM pages JOIN wiki_references ON pages.id = wiki_references.page_id ' +
        'WHERE wiki_references.referenced_name = ? ' +
        "AND wiki_references.link_type = '#{CATEGORY}'"
    names = connection.select_all(sanitize_sql([query, category])).map { |row| row['name'] }
  end
  
  def self.list_categories
    query = "SELECT DISTINCT referenced_name FROM wiki_references WHERE link_type = '#{CATEGORY}'"
    connection.select_all(query).map { |row| row['referenced_name'] }
  end

  def wiki_link?
    linked_page? or wanted_page?
  end

  def linked_page?
    link_type == LINKED_PAGE
  end

  def wanted_page?
    link_type == WANTED_PAGE
  end

  def included_page?
    link_type == INCLUDED_PAGE
  end

end
