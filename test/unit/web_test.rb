require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class WebTest < ActiveSupport::TestCase
  fixtures :system, :webs, :pages, :revisions, :wiki_references
  
  def setup
    @web = webs(:instiki)
  end
  
  def test_pages_by_revision
    add_sample_pages
    assert_equal 'EverBeenHated', @web.select.by_revision.first.name
  end
  
  def test_pages_by_match
    add_sample_pages
    assert_equal 3, @web.select { |page| page.content =~ /me/i }.length
    assert_equal 1, @web.select { |page| page.content =~ /Who/i }.length
    assert_equal 0, @web.select { |page| page.content =~ /none/i }.length
  end
  
  def test_002_references
    add_sample_pages
    assert_equal 1, @web.select.pages_that_reference('EverBeenHated').length
    assert_equal 0, @web.select.pages_that_reference('EverBeenInLove').length
  end
  
  def test_delete
    add_sample_pages
    assert_equal 3, @web.pages.length
    @web.remove_pages([ @web.page('EverBeenInLove') ])
    assert_equal 2, @web.pages(true).length
  end
  
  def test_initialize  
    web = Web.new(:name => 'Wiki2', :address => 'wiki2', :password => '123')
  
    assert_equal 'Wiki2', web.name
    assert_equal 'wiki2', web.address
    assert_equal '123', web.password
  
    # new web should be set for maximum features enabled
    assert_equal :markdownMML, web.markup
    assert_equal '008B26', web.color
    assert !web.safe_mode?
    assert_equal([], web.pages)
    assert web.allow_uploads?
    assert_nil web.additional_style
    assert !web.published?
    assert !web.brackets_only?
    assert !web.count_pages?
    assert_equal 100, web.max_upload_size
  end
  
  def test_initialize_invalid_name
    assert_raises(Instiki::ValidationError) { 
      Web.create(:name => 'Wiki2', :address => "wiki\234", :password => '123') 
    }
  end
  
  def test_new_page_linked_from_mother_page
    # this was a bug in revision 204
    home = @web.add_page('HomePage', 'This page refers to AnotherPage', 
        Time.local(2004, 4, 4, 16, 50), 'Alexey Verkhovsky', x_test_renderer)
    @web.add_page('AnotherPage', 'This is \AnotherPage', 
        Time.local(2004, 4, 4, 16, 51), 'Alexey Verkhovsky', x_test_renderer)

    @web.pages(true)
    assert_equal [home], @web.select.pages_that_link_to('AnotherPage')
  end

  def test_001_orphaned_pages
    add_sample_pages
    home = @web.add_page('HomePage', 
        'This is a home page, it should not be an orphan',
        Time.local(2004, 4, 4, 16, 50), 'AlexeyVerkhovsky', x_test_renderer)
    author = @web.add_page('AlexeyVerkhovsky', 
        'This is an author page, it should not be an orphan',
        Time.local(2004, 4, 4, 16, 50), 'AlexeyVerkhovsky', x_test_renderer)
    self_linked = @web.add_page('SelfLinked', 
        "I am SelfLinked and link to EverBeenInLove\ncategory: fubar",
        Time.local(2004, 4, 4, 16, 50), 'AnonymousCoward', x_test_renderer)
        
    # page that links to itself, and nobody else links to it must be an orphan
    assert_equal ['EverBeenHated', 'SelfLinked'], 
       @web.select.orphaned_pages.collect{ |page| page.name }.sort
    pages_in_category = @web.select.pages_in_category('fubar')
    orphaned_pages = @web.select.orphaned_pages
    assert_equal ['SelfLinked'], 
       (pages_in_category & orphaned_pages).collect{ |page| page.name }.sort
  end  

  def test_page_names_by_author
    page_names_by_author = webs(:test_wiki).page_names_by_author
    assert_equal %w(AnAuthor DavidHeinemeierHansson Guest Me TreeHugger),
        page_names_by_author.keys.sort
    assert_equal %w(FirstPage HomePage), page_names_by_author['DavidHeinemeierHansson']
    assert_equal %w(Oak), page_names_by_author['TreeHugger']
  end

  private
  
  def add_sample_pages
    @in_love = @web.add_page('EverBeenInLove', "Who am I me\ncategory: fubar", 
        Time.local(2004, 4, 4, 16, 50), 'DavidHeinemeierHansson', x_test_renderer)
    @hated = @web.add_page('EverBeenHated', 'I am me EverBeenHated', 
        Time.local(2004, 4, 4, 16, 51), 'DavidHeinemeierHansson', x_test_renderer)
  end
end
