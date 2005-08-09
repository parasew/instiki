require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class WebTest < Test::Unit::TestCase
  fixtures :webs, :pages, :revisions, :system
  
  def setup
    @web = webs(:instiki)
  end
  
  def test_wiki_word_linking
    @web.add_page('SecondPage', 'Yo, yo. Have you EverBeenHated', 
                   Time.now, 'DavidHeinemeierHansson')
    
    assert_equal('<p>Yo, yo. Have you <span class="newWikiWord">Ever Been Hated' + 
        '<a href="../show/EverBeenHated">?</a></span></p>', 
        @web.page("SecondPage").display_content)
    
    @web.add_page('EverBeenHated', 'Yo, yo. Have you EverBeenHated', Time.now, 
                  'DavidHeinemeierHansson')
    assert_equal('<p>Yo, yo. Have you <a class="existingWikiWord" ' +
        'href="../show/EverBeenHated">Ever Been Hated</a></p>', 
        @web.page("SecondPage").display_content)
  end
  
  def test_pages_by_revision
    add_sample_pages
    assert_equal 'EverBeenHated', @web.select.by_revision.first.name
  end
  
  def test_pages_by_match
    add_sample_pages
    assert_equal 2, @web.select { |page| page.content =~ /me/i }.length
    assert_equal 1, @web.select { |page| page.content =~ /Who/i }.length
    assert_equal 0, @web.select { |page| page.content =~ /none/i }.length
  end
  
  def test_references
    add_sample_pages
    assert_equal 1, @web.select.pages_that_reference('EverBeenHated').length
    assert_equal 0, @web.select.pages_that_reference('EverBeenInLove').length
  end
  
  def test_delete
    add_sample_pages
    assert_equal 2, @web.pages.length
    @web.remove_pages([ @web.page('EverBeenInLove') ])
    assert_equal 1, @web.pages(true).length
  end
  
  def test_make_link
    add_sample_pages
    
    existing_page_wiki_url = 
        '<a class="existingWikiWord" href="../show/EverBeenInLove">Ever Been In Love</a>'
    existing_page_published_url = 
        '<a class="existingWikiWord" href="../published/EverBeenInLove">Ever Been In Love</a>'
    existing_page_static_url = 
        '<a class="existingWikiWord" href="EverBeenInLove.html">Ever Been In Love</a>'
    new_page_wiki_url = 
        '<span class="newWikiWord">Unknown Word<a href="../show/UnknownWord">?</a></span>'
    new_page_published_url = 
    new_page_static_url =
        '<span class="newWikiWord">Unknown Word</span>'
    
    # no options
    assert_equal existing_page_wiki_url, @web.make_link('EverBeenInLove')
  
    # :mode => :export
    assert_equal existing_page_static_url, @web.make_link('EverBeenInLove', nil, :mode => :export)
  
    # :mode => :publish
    assert_equal existing_page_published_url, 
        @web.make_link('EverBeenInLove', nil, :mode => :publish)
  
    # new page, no options
    assert_equal new_page_wiki_url, @web.make_link('UnknownWord')
  
    # new page, :mode => :export
    assert_equal new_page_static_url, @web.make_link('UnknownWord', nil, :mode => :export)
  
    # new page, :mode => :publish
    assert_equal new_page_published_url, @web.make_link('UnknownWord', nil, :mode => :publish)
  
    # Escaping special characters in the name
    assert_equal(
        '<span class="newWikiWord">Smith &amp; Wesson<a href="../show/Smith+%26+Wesson">?</a></span>', 
        @web.make_link('Smith & Wesson'))
  
    # optionally using text as the link text
    assert_equal(
      existing_page_published_url.sub(/>Ever Been In Love</, ">Haven't you ever been in love?<"),
      @web.make_link('EverBeenInLove', "Haven't you ever been in love?", :mode => :publish))
  
  end
  
  def test_initialize  
    web = Web.new(:name => 'Wiki2', :address => 'wiki2', :password => '123')
  
    assert_equal 'Wiki2', web.name
    assert_equal 'wiki2', web.address
    assert_equal '123', web.password
  
    # new web should be set for maximum features enabled
    assert_equal :textile, web.markup
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
        Time.local(2004, 4, 4, 16, 50), 'Alexey Verkhovsky')
    @web.add_page('AnotherPage', 'This is \AnotherPage', 
        Time.local(2004, 4, 4, 16, 51), 'Alexey Verkhovsky')

    @web.pages(true)
    assert_equal [home], @web.select.pages_that_link_to('AnotherPage')
  end
  
  def test_orphaned_pages
    add_sample_pages
    home = @web.add_page('HomePage', 
        'This is a home page, it should not be an orphan',
        Time.local(2004, 4, 4, 16, 50), 'AlexeyVerkhovsky')
    author = @web.add_page('AlexeyVerkhovsky', 
        'This is an author page, it should not be an orphan',
        Time.local(2004, 4, 4, 16, 50), 'AlexeyVerkhovsky')
    self_linked = @web.add_page('SelfLinked', 
        'I am me SelfLinked and link to EverBeenInLove',
        Time.local(2004, 4, 4, 16, 50), 'AnonymousCoward')
        
    # page that links to itself, and nobody else links to it must be an orphan
    assert_equal ['EverBeenHated', 'SelfLinked'], 
       @web.select.orphaned_pages.collect{ |page| page.name }.sort
  end  

  private
  
  def add_sample_pages
    @in_love = @web.add_page('EverBeenInLove', 'Who am I me', 
        Time.local(2004, 4, 4, 16, 50), 'DavidHeinemeierHansson')
    @hated = @web.add_page('EverBeenHated', 'I am me EverBeenHated', 
        Time.local(2004, 4, 4, 16, 51), 'DavidHeinemeierHansson')
  end
end
