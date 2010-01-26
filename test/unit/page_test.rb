require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class PageTest < ActiveSupport::TestCase
  fixtures :webs, :pages, :revisions, :system
  
  def setup
    @page = pages(:first_page)
  end


  def test_lock
    assert !@page.locked?(Time.local(2004, 4, 4, 16, 50))

    @page.lock(Time.local(2004, 4, 4, 16, 30), "DavidHeinemeierHansson")

    assert @page.locked?(Time.local(2004, 4, 4, 16, 50))
    assert !@page.locked?(Time.local(2004, 4, 4, 17, 1))

    @page.unlock

    assert !@page.locked?(Time.local(2004, 4, 4, 16, 50))
  end
  
  def test_lock_duration
    @page.lock(Time.local(2004, 4, 4, 16, 30), "DavidHeinemeierHansson")

    assert_equal 15, @page.lock_duration(Time.local(2004, 4, 4, 16, 45))
  end
  
  def test_plain_name
    assert_equal "First Page", @page.plain_name
  end

  def test_revise
    @page.revise('HisWay would be MyWay in kinda lame', @page.name, Time.local(2004, 4, 4, 16, 52), 
        'MarianneSyhler', x_test_renderer)
    @page.reload

    assert_equal 2, @page.revisions.length, 'Should have two revisions'
    assert_equal 'MarianneSyhler', @page.current_revision.author.to_s, 
        'Mary should be the author now'
    assert_equal 'DavidHeinemeierHansson', @page.revisions.first.author.to_s, 
        'David was the first author'
  end
  
  def test_revise_continous_revision
    @page.revise('HisWay would be MyWay in kinda lame', @page.name, Time.local(2004, 4, 4, 16, 55), 
        'MarianneSyhler', x_test_renderer)
    @page.reload
    assert_equal 2, @page.revisions.length
    assert_equal 'HisWay would be MyWay in kinda lame', @page.content

    # consecutive revision by the same author within 30 minutes doesn't create a new revision
    @page.revise('HisWay would be MyWay in kinda update', @page.name, Time.local(2004, 4, 4, 16, 57), 
        'MarianneSyhler', x_test_renderer)
    @page.reload
    assert_equal 2, @page.revisions.length
    assert_equal 'HisWay would be MyWay in kinda update', @page.content
    assert_equal Time.local(2004, 4, 4, 16, 57), @page.revised_at

    # but consecutive revision by another author results in a new revision
    @page.revise('HisWay would be MyWay in the house', @page.name, Time.local(2004, 4, 4, 16, 58), 
        'DavidHeinemeierHansson', x_test_renderer)
    @page.reload
    assert_equal 3, @page.revisions.length
    assert_equal 'HisWay would be MyWay in the house', @page.content

    # consecutive update after 30 minutes since the last one also creates a new revision, 
    # even when it is by the same author
    @page.revise('HisWay would be MyWay in my way', @page.name, Time.local(2004, 4, 4, 17, 30), 
        'DavidHeinemeierHansson', x_test_renderer)
    @page.reload
    assert_equal 4, @page.revisions.length
  end
  
  def test_change_name
    @page.revise('HisWay would be MyWay in my way', 'SecondPage', Time.local(2004, 4, 5, 17, 56), 
        'MarianneSyhler', x_test_renderer)
    @page.reload

    assert_equal "Second Page", @page.plain_name
    assert_equal 2, @page.revisions.length, 'Should have two revisions'
    assert_equal 'MarianneSyhler', @page.current_revision.author.to_s, 
        'Marianne should be the author now'
    assert_equal 'DavidHeinemeierHansson', @page.revisions.first.author.to_s, 
        'David was the first author'
  end

  def test_revise_content_unchanged
    last_revision_before = @page.current_revision
    revisions_number_before = @page.revisions.size
  
    assert_raises(Instiki::ValidationError) { 
      @page.revise(@page.current_revision.content, @page.name, Time.now, 'AlexeyVerkhovsky', x_test_renderer)
    }
    
    assert_equal last_revision_before, @page.current_revision(true)
    assert_equal revisions_number_before, @page.revisions.size
  end

  def test_revise_changes_references_from_wanted_to_linked_for_new_pages
    web = Web.find(1)
    new_page = Page.new(:web => web, :name => 'NewPage')
    new_page.revise('Reference to WantedPage, and to WantedPage2', 'NewPage', Time.now, 'AlexeyVerkhovsky', 
        x_test_renderer)
    
    references = new_page.wiki_references(true)
    assert_equal 2, references.size
    assert_equal 'WantedPage', references[0].referenced_name
    assert_equal WikiReference::WANTED_PAGE, references[0].link_type
    assert_equal 'WantedPage2', references[1].referenced_name
    assert_equal WikiReference::WANTED_PAGE, references[1].link_type

    wanted_page = Page.new(:web => web, :name => 'WantedPage')
    wanted_page.revise('And here it is!', 'WantedPage', Time.now, 'AlexeyVerkhovsky', x_test_renderer)

    # link type stored for NewPage -> WantedPage reference should change from WANTED to LINKED
    # reference NewPage -> WantedPage2 should remain the same
    references = new_page.wiki_references(true)
    assert_equal 2, references.size
    assert_equal 'WantedPage', references[0].referenced_name
    assert_equal WikiReference::LINKED_PAGE, references[0].link_type
    assert_equal 'WantedPage2', references[1].referenced_name
    assert_equal WikiReference::WANTED_PAGE, references[1].link_type
  end

  def test_revise_changes_references_from_wanted_to_linked_for_redirected_pages
    web = Web.find(1)
    new_page = Page.new(:web => web, :name => 'NewPage')
    new_page.revise("Reference to H\xC3\xA1ppyPage, and to WantedPage2", 'NewPage', Time.local(2004, 4, 5, 17, 56), 'AlexeyVerkhovsky', 
        x_test_renderer)
    
    references = new_page.wiki_references(true)
    assert_equal 2, references.size
    p = ''.respond_to?(:force_encoding) ? "H\u00E1ppyPage" : "H\303\241ppyPage"
    assert_equal p, references[0].referenced_name
    assert_equal WikiReference::WANTED_PAGE, references[0].link_type
    assert_equal 'WantedPage2', references[1].referenced_name
    assert_equal WikiReference::WANTED_PAGE, references[1].link_type
    wanted_pages = web.select.wanted_pages
    assert_equal ["HisWay", p, "OverThere", "WantedPage2"], wanted_pages

    my_page = Page.new(:web => web, :name => 'MyPage')
    my_page.revise("[[!redirects H\xC3\xA1ppyPage]]\nAnd here it is!", 'MyPage', Time.now, 'AlexeyVerkhovsky', x_test_renderer)
    my_references = my_page.wiki_references(true)
    assert_equal 1, my_references.size
    assert_equal p, my_references[0].referenced_name
    assert_equal WikiReference::REDIRECTED_PAGE, my_references[0].link_type
    wanted_pages = web.select.wanted_pages
    assert_equal ["HisWay", "OverThere", "WantedPage2"], wanted_pages

    # link type stored for NewPage -> HappyPage reference should change from WANTED to LINKED
    # reference NewPage -> WantedPage2 should remain the same
    references = new_page.wiki_references #(true)
    s = ''.respond_to?(:force_encoding) ? "Reference to <a class='existingWikiWord' href='\.\./show/MyPage'>H\u00E1ppy Page</a>" :
       "Reference to <a class='existingWikiWord' href='\.\./show/MyPage'>H\303\241ppy Page</a>"
    assert_match( s,
         x_test_renderer(new_page.revisions.last).display_content(true) )
    assert_equal 2, references.size
    assert_equal p, references[0].referenced_name
#   Doesn't work, since picking up the change in wiki_references requires a database query.
#    assert_equal WikiReference::LINKED_PAGE, references[0].link_type
    assert_equal 'WantedPage2', references[1].referenced_name
    assert_equal WikiReference::WANTED_PAGE, references[1].link_type
    wanted_pages = web.select.wanted_pages
    assert_equal ["HisWay", "OverThere", "WantedPage2"], wanted_pages
    
    new_page.revise("Reference to H\xC3\xA1ppyPage and to WantedPage2.pdf and [[foo.pdf]]", 'NewPage', Time.now, 'AlexeyVerkhovsky', 
        x_test_renderer)
    references = new_page.wiki_references(true)
    s = ''.respond_to?(:force_encoding) ? "<p>Reference to <a class='existingWikiWord' href='\.\./show/MyPage'>H\u00E1ppy Page</a>" :
        "<p>Reference to <a class='existingWikiWord' href='\.\./show/MyPage'>H\303\241ppy Page</a>"
    assert_equal( s +
      " and to <span class='newWikiWord'>Wanted Page2<a href='../show/WantedPage2'>?</a></span>.pdf " +
      "and <span class='newWikiWord'>foo.pdf<a href='../show/foo.pdf'>?</a></span></p>",
         x_test_renderer(new_page.revisions.last).display_content(true) )
    assert_equal 3, references.size
#   now it works.
    assert_equal p, references[0].referenced_name
    assert_equal WikiReference::LINKED_PAGE, references[0].link_type
    assert_equal 'WantedPage2', references[1].referenced_name
    assert_equal WikiReference::WANTED_PAGE, references[1].link_type
    assert_equal 'foo.pdf', references[2].referenced_name
    assert_equal WikiReference::WANTED_PAGE, references[1].link_type
    wanted_pages = web.select.wanted_pages
    assert_equal ["HisWay", "OverThere", "WantedPage2"], wanted_pages
  end

  def test_rollback
    @page.revise("spot two", @page.name, Time.now, "David", x_test_renderer)
    @page.revise("spot three", @page.name, Time.now + 2000, "David", x_test_renderer)
    assert_equal 3, @page.revisions(true).length, "Should have three revisions"
    @page.current_revision(true)
    @page.rollback(0, Time.now, '127.0.0.1', x_test_renderer)
    assert_equal "HisWay would be MyWay $\\sin(x)\\begin{svg}<svg/>\\end{svg}\\includegraphics[width=3em]{foo}$ in kinda ThatWay in HisWay though MyWay \\\\OverThere -- see SmartEngine in that SmartEngineGUI", @page.current_revision(true).content
  end
end
