class WikiReference < ActiveRecord::Base

  LINKED_PAGE = 'L'
  WANTED_PAGE = 'W'
  INCLUDED_PAGE = 'I'
  CATEGORY = 'C'
  AUTHOR = 'A'
  FILE = 'F'
  WANTED_FILE = 'E'

  belongs_to :page
  validates_inclusion_of :link_type, :in => [LINKED_PAGE, WANTED_PAGE, INCLUDED_PAGE, CATEGORY, AUTHOR, FILE, WANTED_FILE]

  def self.link_type(web, page_name)
    web.has_page?(page_name) ? LINKED_PAGE : WANTED_PAGE
  end

  def self.pages_that_reference(web, page_name)
    query = 'SELECT name FROM pages JOIN wiki_references ' +
      'ON pages.id = wiki_references.page_id ' +
      'WHERE wiki_references.referenced_name = ? ' +
      "AND wiki_references.link_type in ('#{LINKED_PAGE}', '#{WANTED_PAGE}', '#{INCLUDED_PAGE}') " +
      "AND pages.web_id = '#{web.id}'"
    names = connection.select_all(sanitize_sql([query, page_name])).map { |row| row['name'] }
  end

  def self.pages_that_link_to(web, page_name)
    query = 'SELECT name FROM pages JOIN wiki_references ' +
      'ON pages.id = wiki_references.page_id ' +
      'WHERE wiki_references.referenced_name = ? ' +
      "AND wiki_references.link_type in ('#{LINKED_PAGE}','#{WANTED_PAGE}') " +
      "AND pages.web_id = '#{web.id}'"
    names = connection.select_all(sanitize_sql([query, page_name])).map { |row| row['name'] }
  end
  
  def self.pages_that_include(web, page_name)
    query = 'SELECT name FROM pages JOIN wiki_references ' +
      'ON pages.id = wiki_references.page_id ' +
      'WHERE wiki_references.referenced_name = ? ' +
      "AND wiki_references.link_type = '#{INCLUDED_PAGE}' " +
      "AND pages.web_id = '#{web.id}'"
    names = connection.select_all(sanitize_sql([query, page_name])).map { |row| row['name'] }
  end

  def self.pages_in_category(web, category)
    query = 
      "SELECT name FROM pages JOIN wiki_references " +
      "ON pages.id = wiki_references.page_id " +
      "WHERE wiki_references.referenced_name = ? " +
      "AND wiki_references.link_type = '#{CATEGORY}' " +
      "AND pages.web_id = '#{web.id}'"
    names = connection.select_all(sanitize_sql([query, category])).map { |row| row['name'] }
  end
  
  def self.list_categories(web)
    query = "SELECT DISTINCT wiki_references.referenced_name " +
      "FROM wiki_references LEFT OUTER JOIN pages " +
      "ON wiki_references.page_id = pages.id " +
      "WHERE wiki_references.link_type = '#{CATEGORY}' " +
      "AND pages.web_id = '#{web.id}'"
    connection.select_all(query).map { |row| row['referenced_name'] }
  end

  def wiki_word?
    linked_page? or wanted_page?
  end

  def wiki_link?
    linked_page? or wanted_page? or file? or wanted_file?
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
  
  def file?
    link_type == FILE
  end
  
  def wanted_file?
    link_type == WANTED_FILE
  end

end
