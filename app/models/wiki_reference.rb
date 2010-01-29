class WikiReference < ActiveRecord::Base

  LINKED_PAGE = 'L'
  WANTED_PAGE = 'W'
  REDIRECTED_PAGE = 'R'
  INCLUDED_PAGE = 'I'
  CATEGORY = 'C'
  AUTHOR = 'A'
  FILE = 'F'
  WANTED_FILE = 'E'

  belongs_to :page
  validates_inclusion_of :link_type, :in => [LINKED_PAGE, WANTED_PAGE, REDIRECTED_PAGE, INCLUDED_PAGE, CATEGORY, AUTHOR, FILE, WANTED_FILE]

  def referenced_name
    read_attribute(:referenced_name).as_utf8
  end

  def self.link_type(web, page_name)
    if web.has_page?(page_name) || self.page_that_redirects_for(web, page_name)
      LINKED_PAGE
    else
      WANTED_PAGE
    end
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
  
  def self.pages_that_link_to_file(web, file_name)
    query = 'SELECT name FROM pages JOIN wiki_references ' +
      'ON pages.id = wiki_references.page_id ' +
      'WHERE wiki_references.referenced_name = ? ' +
      "AND wiki_references.link_type in ('#{FILE}') " +
      "AND pages.web_id = '#{web.id}'"
    names = connection.select_all(sanitize_sql([query, file_name])).map { |row| row['name'] }
  end
  
  def self.pages_that_include(web, page_name)
    query = 'SELECT name FROM pages JOIN wiki_references ' +
      'ON pages.id = wiki_references.page_id ' +
      'WHERE wiki_references.referenced_name = ? ' +
      "AND wiki_references.link_type = '#{INCLUDED_PAGE}' " +
      "AND pages.web_id = '#{web.id}'"
    names = connection.select_all(sanitize_sql([query, page_name])).map { |row| row['name'] }
  end

  def self.pages_redirected_to(web, page_name)
    names = []
    redirected_pages = []
    page = web.page(page_name)
    redirected_pages.concat page.redirects
    redirected_pages.concat Thread.current[:page_redirects][page] if
            Thread.current[:page_redirects] && Thread.current[:page_redirects][page]
    redirected_pages.uniq.each { |name| names.concat self.pages_that_reference(web, name) }
    names.uniq    
  end

  def self.page_that_redirects_for(web, page_name)
    query = 'SELECT name FROM pages JOIN wiki_references ' +
      'ON pages.id = wiki_references.page_id ' +
      'WHERE wiki_references.referenced_name = ? ' +
      "AND wiki_references.link_type = '#{REDIRECTED_PAGE}' " +
      "AND pages.web_id = '#{web.id}'"
    row = connection.select_one(sanitize_sql([query, page_name]))
    row['name'].as_utf8 if row
  end

  def self.pages_in_category(web, category)
    query = 
      "SELECT name FROM pages JOIN wiki_references " +
      "ON pages.id = wiki_references.page_id " +
      "WHERE wiki_references.referenced_name = ? " +
      "AND wiki_references.link_type = '#{CATEGORY}' " +
      "AND pages.web_id = '#{web.id}'"
    names = connection.select_all(sanitize_sql([query, category])).map { |row| row['name'].as_utf8 }
  end
  
  def self.list_categories(web)
    query = "SELECT DISTINCT wiki_references.referenced_name " +
      "FROM wiki_references LEFT OUTER JOIN pages " +
      "ON wiki_references.page_id = pages.id " +
      "WHERE wiki_references.link_type = '#{CATEGORY}' " +
      "AND pages.web_id = '#{web.id}'"
    connection.select_all(query).map { |row| row['referenced_name'].as_utf8 }
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

  def redirected_page?
    link_type == REDIRECTED_PAGE
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

  def category?
    link_type == CATEGORY
  end

end
