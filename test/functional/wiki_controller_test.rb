#!/usr/bin/env ruby

# Uncomment the line below to enable pdflatex tests; don't forget to comment them again 
# commiting to SVN
# $INSTIKI_TEST_PDFLATEX = true

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require 'wiki_controller'
require 'rexml/document'
require 'tempfile'
require 'zip/zipfilesystem'

# Raise errors beyond the default web-based presentation
class WikiController; def rescue_action(e) logger.error(e); raise e end; end

class WikiControllerTest < ActionController::TestCase
  fixtures :webs, :pages, :revisions, :system, :wiki_references
  
  def setup
    @controller = WikiController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    class << @request.session
      attr_accessor :dbman
    end
    # simulate a cookie session store
    @request.session.dbman = FakeSessionDbMan
    @wiki = Wiki.new
    @web = webs(:test_wiki)
    @home = @page = pages(:home_page)
    @oak = pages(:oak)
    @liquor = pages(:liquor)
    @elephant = pages(:elephant)
    @eternity = Regexp.new('author=.*; path=/; expires=' + Time.utc(2030).strftime("%a, %d-%b-%Y %H:%M:%S GMT"))
    set_tex_header
  end

  def test_authenticate
    set_web_property :password, 'pswd'
  
    get :authenticate, :web => 'wiki1', :password => 'pswd'
    assert_redirected_to :web => 'wiki1', :action => 'show', :id => 'HomePage'
    assert_equal 'pswd', @response.cookies['wiki1']
  end

  def test_authenticate_wrong_password
    set_web_property :password, 'pswd'

    r = process('authenticate', 'web' => 'wiki1', 'password' => 'wrong password')
    assert_redirected_to :action => 'login', :web => 'wiki1'
    assert_nil r.cookies['web_address']
  end

  def test_authors
    @wiki.write_page('wiki1', 'BreakSortingOrder',
        "This page breaks the accidentally correct sorting order of authors",
        Time.now, Author.new('BreakingTheOrder', '127.0.0.2'), test_renderer)

    r = process('authors', 'web' => 'wiki1')

    assert_response(:success)
    assert_equal %w(AnAuthor BreakingTheOrder DavidHeinemeierHansson Guest Me TreeHugger), 
        r.template_objects['authors']
    page_names_by_author = r.template_objects['page_names_by_author'] 
    assert_equal r.template_objects['authors'], page_names_by_author.keys.sort
    assert_equal %w(FirstPage HomePage), page_names_by_author['DavidHeinemeierHansson']
  end

  def test_cancel_edit
    @oak.lock(Time.now, 'Locky')
    assert @oak.locked?(Time.now)
  
    r = process('cancel_edit', 'web' => 'wiki1', 'id' => 'Oak')
    
    assert_redirected_to :action => 'show', :id => 'Oak'
    assert !Page.find(@oak.id).locked?(Time.now)
  end

  def test_edit
    r = process 'edit', 'web' => 'wiki1', 'id' => 'HomePage'
    assert_response(:success)
    assert_equal @wiki.read_page('wiki1', 'HomePage'), r.template_objects['page']
  end

  def test_edit_page_locked_page
    @home.lock(Time.now, 'Locky')
    process 'edit', 'web' => 'wiki1', 'id' => 'HomePage'
    assert_redirected_to :action => 'locked'
  end

  def test_edit_page_break_lock
    @home.lock(Time.now, 'Locky')
    process 'edit', 'web' => 'wiki1', 'id' => 'HomePage', 'break_lock' => 'y'
    assert_response(:success)
    @home = Page.find(@home.id)
    assert @home.locked?(Time.now)
  end

  def test_edit_unknown_page
    process 'edit', 'web' => 'wiki1', 'id' => 'UnknownPage', 'break_lock' => 'y'
    assert_redirected_to :controller => 'wiki', :action => 'show', :web => 'wiki1', 
        :id => 'HomePage'
  end
  
  def test_edit_page_with_special_symbols
    @wiki.write_page('wiki1', 'With : Special /> symbols', 
         'This page has special symbols in the name', Time.now, Author.new('Special', '127.0.0.3'), 
         test_renderer)
    
    r = process 'edit', 'web' => 'wiki1', 'id' => 'With : Special /> symbols'
    assert_response(:success)
    xml = REXML::Document.new(r.body)
    form = REXML::XPath.first(xml, '//form')
    assert_equal '/wiki1/save/With+%3A+Special+%2F%3E+symbols', form.attributes['action']
  end

  def test_export_xhtml
    @request.accept = 'application/xhtml+xml'
    # rollback homepage to a version that is easier to match
    @home.rollback(0, Time.now, 'Rick', test_renderer)
    r = process 'export_html', 'web' => 'wiki1'
    
    assert_response(:success, bypass_body_parsing = true)
    assert_equal 'application/zip', r.headers['Content-Type']
    assert_match /attachment; filename="wiki1-xhtml-\d\d\d\d-\d\d-\d\d-\d\d-\d\d-\d\d.zip"/, 
        r.headers['Content-Disposition']
    assert_equal 'PK', r.body[0..1], 'Content is not a zip file'
    
    # Tempfile doesn't know how to open files with binary flag, hence the two-step process
    Tempfile.open('instiki_export_file') { |f| @tempfile_path = f.path }
    begin 
      File.open(@tempfile_path, 'wb') { |f| f.write(r.body); @exported_file = f.path }
      Zip::ZipFile.open(@exported_file) do |zip| 
        assert_equal %w(Elephant.xhtml FirstPage.xhtml HomePage.xhtml MyWay.xhtml NoWikiWord.xhtml Oak.xhtml SmartEngine.xhtml ThatWay.xhtml index.xhtml liquor.xhtml), zip.dir.entries('.').sort
        assert_match /.*<html .*All about elephants.*<\/html>/, 
            zip.file.read('Elephant.xhtml').gsub(/\s+/, ' ')
        assert_match /.*<html .*All about oak.*<\/html>/, 
            zip.file.read('Oak.xhtml').gsub(/\s+/, ' ')
        assert_match /.*<html .*First revision of the.*HomePage.*end.*<\/html>/, 
            zip.file.read('HomePage.xhtml').gsub(/\s+/, ' ')
        assert_equal '<html xmlns=\'http://www.w3.org/1999/xhtml\'><head><META HTTP-EQUIV="Refresh" CONTENT="0;URL=HomePage.xhtml"></head></html> ', zip.file.read('index.xhtml').gsub(/\s+/, ' ')
      end
    ensure
      File.delete(@tempfile_path) if File.exist?(@tempfile_path)
    end
  end

  def test_export_html
    @request.accept = 'tex/html'
    # rollback homepage to a version that is easier to match
    @home.rollback(0, Time.now, 'Rick', test_renderer)
    r = process 'export_html', 'web' => 'wiki1'
    
    assert_response(:success, bypass_body_parsing = true)
    assert_equal 'application/zip', r.headers['Content-Type']
    assert_match /attachment; filename="wiki1-html-\d\d\d\d-\d\d-\d\d-\d\d-\d\d-\d\d.zip"/, 
        r.headers['Content-Disposition']
    assert_equal 'PK', r.body[0..1], 'Content is not a zip file'
    
    # Tempfile doesn't know how to open files with binary flag, hence the two-step process
    Tempfile.open('instiki_export_file') { |f| @tempfile_path = f.path }
    begin 
      File.open(@tempfile_path, 'wb') { |f| f.write(r.body); @exported_file = f.path }
      Zip::ZipFile.open(@exported_file) do |zip| 
        assert_equal %w(Elephant.html FirstPage.html HomePage.html MyWay.html NoWikiWord.html Oak.html SmartEngine.html ThatWay.html index.html liquor.html), zip.dir.entries('.').sort
        assert_match /.*<html .*All about elephants.*<\/html>/, 
            zip.file.read('Elephant.html').gsub(/\s+/, ' ')
        assert_match /.*<html .*All about oak.*<\/html>/, 
            zip.file.read('Oak.html').gsub(/\s+/, ' ')
        assert_match /.*<html .*First revision of the.*HomePage.*end.*<\/html>/, 
            zip.file.read('HomePage.html').gsub(/\s+/, ' ')
        assert_equal '<html xmlns=\'http://www.w3.org/1999/xhtml\'><head><META HTTP-EQUIV="Refresh" CONTENT="0;URL=HomePage.html"></head></html> ', zip.file.read('index.html').gsub(/\s+/, ' ')
      end
    ensure
      File.delete(@tempfile_path) if File.exist?(@tempfile_path)
    end
  end
  
  def test_export_html_no_layout    
    r = process 'export_html', 'web' => 'wiki1', 'layout' => 'no'
    
    assert_response(:success, bypass_body_parsing = true)
    assert_equal 'application/zip', r.headers['Content-Type']
    assert_match /attachment; filename="wiki1-x?html-\d\d\d\d-\d\d-\d\d-\d\d-\d\d-\d\d.zip"/, 
        r.headers['Content-Disposition']
    assert_equal 'PK', r.body[0..1], 'Content is not a zip file'
  end

  def test_export_markup
    r = process 'export_markup', 'web' => 'wiki1'

    assert_response(:success, bypass_body_parsing = true)
    assert_equal 'application/zip', r.headers['Content-Type']
    assert_match /attachment; filename="wiki1-markdownMML-\d\d\d\d-\d\d-\d\d-\d\d-\d\d-\d\d.zip"/, 
        r.headers['Content-Disposition']
    assert_equal 'PK', r.body[0..1], 'Content is not a zip file'
  end


  if ENV['INSTIKI_TEST_LATEX'] or defined? $INSTIKI_TEST_PDFLATEX

#    def test_export_pdf
#      r = process 'export_pdf', 'web' => 'wiki1'
#      assert_response(:success, bypass_body_parsing = true)
#      assert_equal 'application/pdf', r.headers['Content-Type']
#      assert_match /attachment; filename="wiki1-tex-\d\d\d\d-\d\d-\d\d-\d\d-\d\d-\d\d.pdf"/, 
#          r.headers['Content-Disposition']
#      assert_equal '%PDF', r.body[0..3]
#      assert_equal "EOF\n", r.body[-4..-1]
#    end

  else
#    puts 'Warning: tests involving pdflatex are very slow, therefore they are disabled by default.'
#    puts '         Set environment variable INSTIKI_TEST_PDFLATEX or global Ruby variable'
#    puts '         $INSTIKI_TEST_PDFLATEX to enable them.'
  end
  
#  def test_export_tex    
#    r = process 'export_tex', 'web' => 'wiki1'
#
#    assert_response(:success, bypass_body_parsing = true)
#    assert_equal 'application/octet-stream', r.headers['Content-Type']
#    assert_match /attachment; filename="wiki1-tex-\d\d\d\d-\d\d-\d\d-\d\d-\d\d-\d\d.tex"/, 
#        r.headers['Content-Disposition']
#    assert_equal '\documentclass', r.body[0..13], 'Content is not a TeX file'
#  end

  def test_feeds
    process('feeds', 'web' => 'wiki1')
  end

  def test_index
    # delete extra web fixture
    webs(:instiki).destroy
    process('index')
    assert_redirected_to :web => 'wiki1', :action => 'show', :id => 'HomePage'
  end

  def test_index_multiple_webs
    @wiki.create_web('Test Wiki 2', 'wiki2')
    process('index')
    assert_redirected_to :action => 'web_list'
  end

  def test_index_multiple_webs_web_explicit
    @wiki.create_web('Test Wiki 2', 'wiki2')
    process('index', 'web' => 'wiki2')
    assert_redirected_to :web => 'wiki2', :action => 'show', :id => 'HomePage'
  end

  def test_index_wiki_not_initialized
    use_blank_wiki
    process('index')
    assert_redirected_to :controller => 'admin', :action => 'create_system'
  end


  def test_list
    r = process('list', 'web' => 'wiki1')

    assert_equal ['animals', 'trees'], r.template_objects['categories']
    assert_nil r.template_objects['category']
    assert_equal [@elephant, pages(:first_page), @home, pages(:my_way), pages(:no_wiki_word), 
                  @oak, pages(:smart_engine), pages(:that_way), @liquor], 
                 r.template_objects['pages_in_category']
  end


  def test_locked
    @home.lock(Time.now, 'Locky')
    r = process('locked', 'web' => 'wiki1', 'id' => 'HomePage')
    assert_response(:success)
    assert_equal @home, r.template_objects['page']
  end


  def test_login
    r = process 'login', 'web' => 'wiki1'
    assert_response(:success)
    # this action goes straight to the templates
  end


  def test_new
    r = process('new', 'id' => 'NewPage', 'web' => 'wiki1')
    assert_response(:success)
    assert_equal 'AnonymousCoward', r.template_objects['author']
    assert_equal 'NewPage', r.template_objects['page_name']
  end


  if ENV['INSTIKI_TEST_LATEX'] or defined? $INSTIKI_TEST_PDFLATEX

#    def test_pdf
#      assert RedClothForTex.available?, 'Cannot do test_pdf when pdflatex is not available'
#      r = process('pdf', 'web' => 'wiki1', 'id' => 'HomePage')
#      assert_response(:success, bypass_body_parsing = true)
#
#      assert_equal '%PDF', r.body[0..3]
#      assert_equal "EOF\n", r.body[-4..-1]
#
#      assert_equal 'application/pdf', r.headers['Content-Type']
#      assert_match /attachment; filename="HomePage-wiki1-\d\d\d\d-\d\d-\d\d-\d\d-\d\d-\d\d.pdf"/, 
#          r.headers['Content-Disposition']
#    end

  end


  def test_print
    r = process('print', 'web' => 'wiki1', 'id' => 'HomePage')

    assert_response(:success)
    assert_equal :show, r.template_objects['link_mode']
  end


  def test_published
    set_web_property :published, true
    
    r = process('published', 'web' => 'wiki1', 'id' => 'HomePage')
    
    assert_response(:success)
    assert_equal @home, r.template_objects['page']
    assert_match /<a class='existingWikiWord' href='http:\/\/test.host\/wiki1\/published\/ThatWay'>That Way<\/a>/, r.body

    r = process('show', 'web' => 'wiki1', 'id' => 'HomePage')
    
    assert_response(:success)
    assert_equal @home, r.template_objects['page']
    assert_match /<a class='existingWikiWord' href='http:\/\/test.host\/wiki1\/show\/ThatWay'>That Way<\/a>/, r.body
  end


  def test_published_web_not_published
    set_web_property :published, false
    
    r = process('published', 'web' => 'wiki1', 'id' => 'HomePage')

    assert_response :missing
  end

  def test_published_should_render_homepage_if_no_page_specified
    set_web_property :published, true
    
    r = process('published', 'web' => 'wiki1')
    
    assert_response(:success)
    assert_equal @home, r.template_objects['page']
  end


  def test_recently_revised
    r = process('recently_revised', 'web' => 'wiki1')
    assert_response(:success)
    
    assert_equal %w(animals trees), r.template_objects['categories']
    assert_nil r.template_objects['category']
    all_pages = @elephant, pages(:first_page), @home, pages(:my_way), pages(:no_wiki_word), 
                @oak, pages(:smart_engine), pages(:that_way), @liquor
    assert_equal all_pages, r.template_objects['pages_in_category']
    
    pages_by_day = r.template_objects['pages_by_day']
    assert_not_nil pages_by_day
    pages_by_day_size = pages_by_day.keys.inject(0) { |sum, day| sum + pages_by_day[day].size }
    assert_equal all_pages.size, pages_by_day_size
    all_pages.each do |page| 
      day = Date.new(page.revised_at.year, page.revised_at.month, page.revised_at.day)
      assert pages_by_day[day].include?(page)
    end
    
    assert_equal 'the web', r.template_objects['set_name']
  end
  
  def test_recently_revised_with_categorized_page
    page2 = @wiki.write_page('wiki1', 'Page2',
        "Page2 contents.\n" +
        "category: categorized", 
        Time.now, Author.new('AnotherAuthor', '127.0.0.2'), test_renderer)
      
    r = process('recently_revised', 'web' => 'wiki1')
    assert_response(:success)
    
    assert_equal %w(animals categorized trees), r.template_objects['categories']
    # no category is specified in params
    assert_nil r.template_objects['category']
    assert_equal [@elephant, pages(:first_page), @home, pages(:my_way), pages(:no_wiki_word), @oak, page2, pages(:smart_engine), pages(:that_way), @liquor], r.template_objects['pages_in_category'],
        "Pages are not as expected: " +
        r.template_objects['pages_in_category'].map {|p| p.name}.inspect
    assert_equal 'the web', r.template_objects['set_name']
  end

  def test_recently_revised_with_categorized_page_multiple_categories
    r = process('recently_revised', 'web' => 'wiki1')
    assert_response(:success)

    assert_equal ['animals', 'trees'], r.template_objects['categories']
    # no category is specified in params
    assert_nil r.template_objects['category']
    assert_equal [@elephant, pages(:first_page), @home, pages(:my_way), pages(:no_wiki_word), @oak, pages(:smart_engine), pages(:that_way), @liquor], r.template_objects['pages_in_category'], 
        "Pages are not as expected: " +
        r.template_objects['pages_in_category'].map {|p| p.name}.inspect
    assert_equal 'the web', r.template_objects['set_name']
  end

  def test_recently_revised_with_specified_category
    r = process('recently_revised', 'web' => 'wiki1', 'category' => 'animals')
    assert_response(:success)
    
    assert_equal ['animals', 'trees'], r.template_objects['categories']
    # no category is specified in params
    assert_equal 'animals', r.template_objects['category']
    assert_equal [@elephant], r.template_objects['pages_in_category']
    assert_equal "category 'animals'", r.template_objects['set_name']
  end


  def test_revision
    r = process 'revision', 'web' => 'wiki1', 'id' => 'HomePage', 'rev' => '1'

    assert_response(:success)
    assert_equal @home, r.template_objects['page']
    assert_equal @home.revisions[0], r.template_objects['revision'] 
  end
  

  def test_rollback
    # rollback shows a form where a revision can be edited.
    # its assigns the same as or revision
    r = process 'rollback', 'web' => 'wiki1', 'id' => 'HomePage', 'rev' => '1'

    assert_response(:success)
    assert_equal @home, r.template_objects['page']
    assert_equal @home.revisions[0], r.template_objects['revision']
  end

  def test_atom_with_content
    r = process 'atom_with_content', 'web' => 'wiki1'

    assert_response(:success)
    pages = r.template_objects['pages_by_revision']
    assert_equal [@elephant, @liquor, @oak, pages(:no_wiki_word), pages(:that_way), pages(:smart_engine),
          pages(:my_way), pages(:first_page), @home], pages,
        "Pages are not as expected: #{pages.map {|p| p.name}.inspect}"
    assert !r.template_objects['hide_description']
  end

  def test_atom_with_content_when_blocked
    @web.update_attributes(:password => 'aaa', :published => false)
    @web = Web.find(@web.id)
    
    r = process 'atom_with_content', 'web' => 'wiki1'
    
    assert_equal 403, r.response_code
  end
  

  def test_atom_with_headlines
    @title_with_spaces = @wiki.write_page('wiki1', 'Title With Spaces', 
      'About spaces', 1.hour.ago, Author.new('TreeHugger', '127.0.0.2'), test_renderer)
    
    @request.host = 'localhost'
    @request.port = 8080
  
    r = process 'atom_with_headlines', 'web' => 'wiki1'

    assert_response(:success)
    pages = r.template_objects['pages_by_revision']
    assert_equal [@elephant, @liquor, @title_with_spaces, @oak, pages(:no_wiki_word), pages(:that_way), pages(:smart_engine), pages(:my_way), pages(:first_page), @home], pages, "Pages are not as expected: #{pages.map {|p| p.name}.inspect}"
    assert r.template_objects['hide_description']
    
    xml = REXML::Document.new(r.body)

    expected_page_links =
        ['http://localhost:8080/wiki1/show/Elephant',
         'http://localhost:8080/wiki1/show/Title+With+Spaces',
         'http://localhost:8080/wiki1/show/Oak',
         'http://localhost:8080/wiki1/show/NoWikiWord',
         'http://localhost:8080/wiki1/show/ThatWay',
         'http://localhost:8080/wiki1/show/SmartEngine',
         'http://localhost:8080/wiki1/show/MyWay',
         'http://localhost:8080/wiki1/show/FirstPage',
         'http://localhost:8080/wiki1/show/HomePage',
         ]

     assert_tag :tag => 'link',
                :parent => {:tag => 'feed'},
                :attributes => { :rel => 'alternate',
                                 :href => 'http://localhost:8080/wiki1/show/HomePage'}
    expected_page_links.each do |link|
       assert_tag :tag => 'link',
                :parent => {:tag => 'entry'},
                :attributes => {:href => link }
    end
  end

  def test_atom_switch_links_to_published
    @web.update_attributes(:password => 'aaa', :published => true)
    @web = Web.find(@web.id)
    
    @request.host = 'foo.bar.info'
    @request.port = 80

    r = process 'atom_with_headlines', 'web' => 'wiki1'

    assert_response(:success)
    xml = REXML::Document.new(r.body)

    expected_page_links =
        ['http://foo.bar.info/wiki1/published/Elephant',
         'http://foo.bar.info/wiki1/published/Oak',
         'http://foo.bar.info/wiki1/published/NoWikiWord',
         'http://foo.bar.info/wiki1/published/ThatWay',
         'http://foo.bar.info/wiki1/published/SmartEngine',
         'http://foo.bar.info/wiki1/published/MyWay',
         'http://foo.bar.info/wiki1/published/FirstPage',
         'http://foo.bar.info/wiki1/published/HomePage']
    
    assert_tag :tag => 'link',
               :parent =>{:tag =>'feed'},
               :attributes => {:rel => 'alternate',
                               :href => 'http://foo.bar.info/wiki1/published/HomePage'}
    expected_page_links.each do |link|
      assert_tag :tag => 'link',
                 :parent => {:tag => 'entry'},
                 :attributes => {:href => link}
    end
  end

#  def test_atom_with_params
#    setup_wiki_with_30_pages
#
#    r = process 'atom_with_headlines', 'web' => 'wiki1'
#    assert_response(:success)
#    pages = r.template_objects['pages_by_revision']
#    assert_equal 15, pages.size, 15
#    
#    r = process 'atom_with_headlines', 'web' => 'wiki1', 'limit' => '5'
#    assert_response(:success)
#    pages = r.template_objects['pages_by_revision']
#    assert_equal 5, pages.size
#    
#    r = process 'atom_with_headlines', 'web' => 'wiki1', 'limit' => '25'
#    assert_response(:success)
#    pages = r.template_objects['pages_by_revision']
#    assert_equal 25, pages.size
#    
#    r = process 'atom_with_headlines', 'web' => 'wiki1', 'limit' => 'all'
#    assert_response(:success)
#    pages = r.template_objects['pages_by_revision']
#    assert_equal 38, pages.size
#    
#    r = process 'atom_with_headlines', 'web' => 'wiki1', 'start' => '1976-10-16'
#    assert_response(:success)
#    pages = r.template_objects['pages_by_revision']
#    assert_equal 23, pages.size
#    
#    r = process 'atom_with_headlines', 'web' => 'wiki1', 'end' => '1976-10-16'
#    assert_response(:success)
#    pages = r.template_objects['pages_by_revision']
#    assert_equal 15, pages.size
#    
#    r = process 'atom_with_headlines', 'web' => 'wiki1', 'start' => '1976-10-01', 'end' => '1976-10-06'
#    assert_response(:success)
#    pages = r.template_objects['pages_by_revision']
#    assert_equal 5, pages.size
#  end

  def test_atom_title_with_ampersand
    # was ticket:143
    # Since we're declaring <title> to be of type="html", the content is unescaped once before interpreting.
    # Evidently, the desired behaviour is that the final result be HTML-encoded. Hence the double-encoding here.
    @wiki.write_page('wiki1', 'Title&With&Ampersands', 
      'About spaces', 1.hour.ago, Author.new('NitPicker', '127.0.0.3'), test_renderer)

    r = process 'atom_with_headlines', 'web' => 'wiki1'

    assert r.body.include?('<title type="html">Home Page</title>')
    assert r.body.include?('<title type="html">Title&amp;amp;With&amp;amp;Ampersands</title>')
  end

  def test_atom_timestamp    
    new_page = @wiki.write_page('wiki1', 'PageCreatedAtTheBeginningOfCtime', 
      'Created on 1 Jan 1970 at 0:00:00 Z', Time.at(0), Author.new('NitPicker', '127.0.0.3'),
      test_renderer)

    r = process 'atom_with_headlines', 'web' => 'wiki1'
    assert_tag :tag =>'published',
               :parent => {:tag => 'entry'},
               :content => Time.now.getgm.strftime("%Y-%m-%dT%H:%M:%SZ")
  end
  
  def test_save
    r = process 'save', 'web' => 'wiki1', 'id' => 'NewPage', 'content' => 'Contents of a new page', 
      'author' => 'AuthorOfNewPage'
    
    assert_redirected_to :web => 'wiki1', :action => 'show', :id => 'NewPage'
    assert_equal 'AuthorOfNewPage', r.cookies['author']
    assert_match @eternity, r.headers["Set-Cookie"][0]
    new_page = @wiki.read_page('wiki1', 'NewPage')
    assert_equal 'Contents of a new page', new_page.content
    assert_equal 'AuthorOfNewPage', new_page.author
  end

  def test_save_not_utf8
    r = process 'save', 'web' => 'wiki1', 'id' => 'NewPage', 'content' => "Contents of a new page\r\n\000", 
      'author' => 'AuthorOfNewPage'
    
    assert_redirected_to :web => 'wiki1', :action => 'new', :id => 'NewPage', :content => ''
    assert_equal 'AuthorOfNewPage', r.cookies['author']
    assert_match @eternity, r.headers["Set-Cookie"][0]
  end

  def test_save_not_utf8_ncr
    r = process 'save', 'web' => 'wiki1', 'id' => 'NewPage', 'content' => "Contents of a new page\r\n&#xfffe;", 
      'author' => 'AuthorOfNewPage'
    
    assert_redirected_to :web => 'wiki1', :action => 'new', :id => 'NewPage'
    assert_equal 'AuthorOfNewPage', r.cookies['author']
    assert_match @eternity, r.headers["Set-Cookie"][0]
  end

  def test_save_not_utf8_dec_ncr
    r = process 'save', 'web' => 'wiki1', 'id' => 'NewPage', 'content' => "Contents of a new page\r\n&#65535;", 
      'author' => 'AuthorOfNewPage'
    
    assert_redirected_to :web => 'wiki1', :action => 'new', :id => 'NewPage'
    assert_equal 'AuthorOfNewPage', r.cookies['author']
    assert_match @eternity, r.headers["Set-Cookie"][0]
  end

  def test_save_new_revision_of_existing_page
    @home.lock(Time.now, 'Batman')
    current_revisions = @home.revisions.size

    r = process 'save', 'web' => 'wiki1', 'id' => 'HomePage', 'content' => 'Revised HomePage', 
      'author' => 'Batman'

    assert_redirected_to :web => 'wiki1', :action => 'show', :id => 'HomePage'
    assert_equal 'Batman', r.cookies['author']
    home_page = @wiki.read_page('wiki1', 'HomePage')
    assert_equal current_revisions+1, home_page.revisions.size
    assert_equal 'Revised HomePage', home_page.content
    assert_equal 'Batman', home_page.author
    assert !home_page.locked?(Time.now)
  end

  def test_save_new_revision_of_existing_page_invalid_utf8
    @home.lock(Time.now, 'Batman')
    current_revisions = @home.revisions.size

    r = process 'save', 'web' => 'wiki1', 'id' => 'HomePage', 'content' => "Revised HomePage\000", 
      'author' => 'Batman'

    assert_redirected_to :web => 'wiki1', :action => 'edit', :id => 'HomePage',
       :content => 'HisWay would be MyWay $\sin(x)\begin{svg}<svg/>\end{svg}\includegraphics[width' +
                   '=3em]{foo}$ in kinda ThatWay in HisWay though MyWay \OverThere -- see SmartEng' +
                   'ine in that SmartEngineGUI'
    assert_equal 'Batman', r.cookies['author']
    home_page = @wiki.read_page('wiki1', 'HomePage')
    assert_equal current_revisions, home_page.revisions.size
    assert_equal 'DavidHeinemeierHansson', home_page.author
    assert !home_page.locked?(Time.now)
  end

  def test_dnsbl_filter_deny_action
    @request.remote_addr = "127.0.0.2"
    r = process 'save', 'web' => 'wiki1', 'id' => 'NewPage', 'content' => "Contents of a new page\r\n",
      'author' => 'AuthorOfNewPage'

    assert_equal 403, r.response_code
  end

  def test_dnsbl_filter_allow_action
    @request.remote_addr = "127.0.0.2"
    r = process 'show', 'id' => 'Oak', 'web' => 'wiki1'
    assert_response :success
    assert_tag :content => /All about oak/
  end

  def test_spam_filters
    revisions_before = @home.revisions.size
    @home.lock(Time.now, 'AnAuthor')
    r = process 'save', {'web' => 'wiki1', 'id' => 'HomePage',
        'content' => @home.revisions.last.content.dup + "\n Try viagra.\n",
        'author' => 'SomeOtherAuthor'}, {:return_to => '/wiki1/show/HomePage'}
    assert_redirected_to :action => 'edit', :web => 'wiki1', :id => 'HomePage'
    assert r.flash[:error].to_s == "Your edit was blocked by spam filtering"
  end

  def test_save_new_revision_identical_to_last
    revisions_before = @home.revisions.size
    @home.lock(Time.now, 'AnAuthor')
  
    r = process 'save', {'web' => 'wiki1', 'id' => 'HomePage', 
        'content' => @home.revisions.last.content.dup, 
        'author' => 'SomeOtherAuthor'}, {:return_to => '/wiki1/show/HomePage'}

    assert_redirected_to :action => 'edit', :web => 'wiki1', :id => 'HomePage'
    assert r.flash[:error].to_s == "You have tried to save page 'HomePage' without changing its content"

    revisions_after = @home.revisions.size
    assert_equal revisions_before, revisions_after
    @home = Page.find(@home.id)
    assert !@home.locked?(Time.now), 'HomePage should be unlocked if an edit was unsuccessful'
  end

  def test_save_new_revision_identical_to_last_but_new_name
    revisions_before = @liquor.revisions.size
    @liquor.lock(Time.now, 'AnAuthor')
  
    r = process 'save', {'web' => 'wiki1', 'id' => 'liquor', 
        'content' => @liquor.revisions.last.content.dup, 'new_name' => 'booze',
        'author' => 'SomeOtherAuthor'}, {:return_to => '/wiki1/show/booze'}

    assert_redirected_to :action => 'show', :web => 'wiki1', :id => 'booze'

    revisions_after = @liquor.revisions.size
    assert_equal revisions_before + 1, revisions_after
    @booze = Page.find(@liquor.id)
    assert !@booze.locked?(Time.now), 'booze should be unlocked if an edit was unsuccessful'
  end

  def test_save_blank_author
    r = process 'save', 'web' => 'wiki1', 'id' => 'NewPage', 'content' => 'Contents of a new page', 
      'author' => ''
    new_page = @wiki.read_page('wiki1', 'NewPage')
    assert_equal 'AnonymousCoward', new_page.author

    r = process 'save', 'web' => 'wiki1', 'id' => 'AnotherPage', 'content' => 'Contents of a new page', 
      'author' => '   '

    another_page = @wiki.read_page('wiki1', 'AnotherPage')
    assert_equal 'AnonymousCoward', another_page.author
  end

  def test_save_invalid_author_name
    r = process 'save', 'web' => 'wiki1', 'id' => 'NewPage', 'content' => 'Contents of a new page', 
      'author' => 'foo.bar'
    assert_redirected_to :action => 'new', :web => 'wiki1', :id => 'NewPage'
    assert r.flash[:error].to_s == 'Your name cannot contain a "."'

    r = process 'save', 'web' => 'wiki1', 'id' => 'AnotherPage', 'content' => 'Contents of a new page', 
      'author' => "\000"

    assert_redirected_to :action => 'new', :web => 'wiki1', :id => 'AnotherPage'
    assert r.flash[:error].to_s == "Your name was not valid utf-8"
  end

  def test_search
    r = process 'search', 'web' => 'wiki1', 'query' => '\s[A-Z]ak'
    
    assert_redirected_to :action => 'show', :id => 'Oak'
  end

  def test_search_multiple_results
    r = process 'search', 'web' => 'wiki1', 'query' => 'All about'
    
    assert_response(:success)
    assert_equal 'All about', r.template_objects['query']
    assert_equal [@elephant, @oak], r.template_objects['results']
    assert_equal [], r.template_objects['title_results']
  end

  def test_search_by_content_and_title
    r = process 'search', 'web' => 'wiki1', 'query' => '(Oak|Elephant)'
    
    assert_response(:success)
    assert_equal '(Oak|Elephant)', r.template_objects['query']
    assert_equal [@elephant, @oak], r.template_objects['results']
    assert_equal [@elephant, @oak], r.template_objects['title_results']
  end

  def test_search_zero_results
    r = process 'search', 'web' => 'wiki1', 'query' => 'non-existant text'
    
    assert_response(:success)
    assert_equal [], r.template_objects['results']
    assert_equal [], r.template_objects['title_results']
  end

  def test_search_null_in_query
    r = process 'search', 'web' => 'wiki1', 'query' => "\x00"
    
    assert_response(400)
    assert_match /Your query string was not valid utf-8/, r.body
  end

  def test_search_FFFF_in_query
    r = process 'search', 'web' => 'wiki1', 'query' => "\xEF\xBF\xBF"
    
    assert_response(400)
    assert_match /Your query string was not valid utf-8/, r.body
  end

  def test_search_FFFD_in_query
    r = process 'search', 'web' => 'wiki1', 'query' => "\xEF\xBF\xBD"
    
    assert_response(:success)
    assert_equal [], r.template_objects['results']
    assert_equal [], r.template_objects['title_results']
  end

  def test_show_page
    r = process 'show', 'id' => 'Oak', 'web' => 'wiki1'
    assert_response :success
    assert_tag :content => /All about oak/
  end

  def test_show_page_with_multiple_revisions
    @wiki.write_page('wiki1', 'HomePage', 'Second revision of the HomePage end', Time.now, 
        Author.new('AnotherAuthor', '127.0.0.2'), test_renderer)

    r = process('show', 'id' => 'HomePage', 'web' => 'wiki1')

    assert_response :success
    assert_match /Second revision of the <a.*HomePage.*<\/a> end/, r.body
  end

  def test_recursive_include
    @wiki.write_page('wiki1', 'HomePage', 'Self-include: [[!include HomePage]]', Time.now, 
        Author.new('AnotherAuthor', '127.0.0.2'), test_renderer)

    r = process('show', 'id' => 'HomePage', 'web' => 'wiki1')

    assert_response :success
    assert_match /<em>Recursive include detected: HomePage \342\206\222 HomePage<\/em>/, r.body
  end

  def test_recursive_include_II
    @wiki.write_page('wiki1', 'Foo', "extra fun [[!include HomePage]]", Time.now, 
        Author.new('AnotherAuthor', '127.0.0.2'), test_renderer)
    @wiki.write_page('wiki1', 'HomePage', "Recursive-include:\n\n[[!include Foo]]", Time.now, 
        Author.new('AnotherAuthor', '127.0.0.2'), test_renderer)

    r = process('show', 'id' => 'HomePage', 'web' => 'wiki1')

    assert_response :success
    assert_match /<p>Recursive-include:<\/p>\n\n<p>extra fun <em>Recursive include detected: Foo \342\206\222 Foo<\/em><\/p>/, r.body
  end
  
  def test_recursive_include_III
    @wiki.write_page('wiki1', 'Bar', "extra fun\n\n[[!include HomePage]]", Time.now, 
        Author.new('AnotherAuthor', '127.0.0.2'), test_renderer)
    @wiki.write_page('wiki1', 'Foo', "[[!include Bar]]\n\n[[!include Bar]]", Time.now, 
        Author.new('AnotherAuthor', '127.0.0.2'), test_renderer)
    @wiki.write_page('wiki1', 'HomePage', "Recursive-include:\n\n[[!include Foo]]", Time.now, 
        Author.new('AnotherAuthor', '127.0.0.2'), test_renderer)

    r = process('show', 'id' => 'HomePage', 'web' => 'wiki1')

    assert_response :success
    assert_match /<p>Recursive-include:<\/p>\n\n<p>extra fun<\/p>\n<em>Recursive include detected: Bar \342\206\222 Bar<\/em>/, r.body
  end

  def test_nonrecursive_include
    @wiki.write_page('wiki1', 'Bar', "extra fun\n\n[[HomePage]]", Time.now, 
        Author.new('AnotherAuthor', '127.0.0.2'), test_renderer)
    @wiki.write_page('wiki1', 'Foo', "[[!include Bar]]\n\n[[!include Bar]]", Time.now, 
        Author.new('AnotherAuthor', '127.0.0.2'), test_renderer)
    @wiki.write_page('wiki1', 'HomePage', "Nonrecursive-include:\n\n[[!include Foo]]", Time.now, 
        Author.new('AnotherAuthor', '127.0.0.2'), test_renderer)

    r = process('show', 'id' => 'HomePage', 'web' => 'wiki1')

    assert_response :success
    assert_match /<p>Nonrecursive-include:<\/p>\n\n<p>extra fun<\/p>\n\n<p><a class='existingWikiWord' href='http:\/\/test.host\/wiki1\/show\/HomePage'>HomePage<\/a><\/p>/, r.body
  end
  
  def test_show_page_nonexistant_page
    process('show', 'id' => 'UnknownPage', 'web' => 'wiki1')
    assert_redirected_to :web => 'wiki1', :action => 'new', :id => 'UnknownPage'
  end

  def test_show_no_page
    r = process('show', 'id' => '', 'web' => 'wiki1')
    assert_response :missing
    
    r = process('show', 'web' => 'wiki1')
    assert_response :missing
  end

  def set_tex_header
    @tex_header1 = %q!\documentclass[12pt,titlepage]{article}

\usepackage{amsmath}
\usepackage{amsfonts}
\usepackage{amssymb}
\usepackage{amsthm}
!
    @tex_header2 = %q!\usepackage{graphicx}
\usepackage{color}
\usepackage{ucs}
\usepackage[utf8x]{inputenc}
\usepackage{hyperref}

%----Macros----------
%
% Unresolved issues:
%
%  \righttoleftarrow
%  \lefttorightarrow
%
%  \color{} with HTML colorspec
%  \bgcolor
%  \array

% Of the standard HTML named colors, white, black, red, green, blue and yellow
% are predefined in the color package. Here are the rest.
\definecolor{aqua}{rgb}{0, 1.0, 1.0}
\definecolor{fuschia}{rgb}{1.0, 0, 1.0}
\definecolor{gray}{rgb}{0.502, 0.502, 0.502}
\definecolor{lime}{rgb}{0, 1.0, 0}
\definecolor{maroon}{rgb}{0.502, 0, 0}
\definecolor{navy}{rgb}{0, 0, 0.502}
\definecolor{olive}{rgb}{0.502, 0.502, 0}
\definecolor{purple}{rgb}{0.502, 0, 0.502}
\definecolor{silver}{rgb}{0.753, 0.753, 0.753}
\definecolor{teal}{rgb}{0, 0.502, 0.502}

% Because of conflicts, \space and \mathop are converted to
% \itexspace and \operatorname during preprocessing.

% itex: \space{ht}{dp}{wd}
%
% Height and baseline depth measurements are in units of tenths of an ex while
% the width is measured in tenths of an em.
\makeatletter
\newdimen\itex@wd%
\newdimen\itex@dp%
\newdimen\itex@thd%
\def\itexspace#1#2#3{\itex@wd=#3em%
\itex@wd=0.1\itex@wd%
\itex@dp=#2ex%
\itex@dp=0.1\itex@dp%
\itex@thd=#1ex%
\itex@thd=0.1\itex@thd%
\advance\itex@thd\the\itex@dp%
\makebox[\the\itex@wd]{\rule[-\the\itex@dp]{0cm}{\the\itex@thd}}}
\makeatother

% \tensor and \multiscript
\makeatletter
\newif\if@sup
\newtoks\@sups
\def\append@sup#1{\edef\act{\noexpand\@sups={\the\@sups #1}}\act}%
\def\reset@sup{\@supfalse\@sups={}}%
\def\mk@scripts#1#2{\if #2/ \if@sup ^{\the\@sups}\fi \else%
  \ifx #1_ \if@sup ^{\the\@sups}\reset@sup \fi {}_{#2}%
  \else \append@sup#2 \@suptrue \fi%
  \expandafter\mk@scripts\fi}
\def\tensor#1#2{\reset@sup#1\mk@scripts#2_/}
\def\multiscripts#1#2#3{\reset@sup{}\mk@scripts#1_/#2%
  \reset@sup\mk@scripts#3_/}
\makeatother

% \slash
\makeatletter
\newbox\slashbox \setbox\slashbox=\hbox{$/$}
\def\itex@pslash#1{\setbox\@tempboxa=\hbox{$#1$}
  \@tempdima=0.5\wd\slashbox \advance\@tempdima 0.5\wd\@tempboxa
  \copy\slashbox \kern-\@tempdima \box\@tempboxa}
\def\slash{\protect\itex@pslash}
\makeatother

% Renames \sqrt as \oldsqrt and redefine root to result in \sqrt[#1]{#2}
\let\oldroot\root
\def\root#1#2{\oldroot #1 \of{#2}}

% Manually declare the txfonts symbolsC font
\DeclareSymbolFont{symbolsC}{U}{txsyc}{m}{n}
\SetSymbolFont{symbolsC}{bold}{U}{txsyc}{bx}{n}
\DeclareFontSubstitution{U}{txsyc}{m}{n}

% Manually declare the stmaryrd font
\DeclareSymbolFont{stmry}{U}{stmry}{m}{n}
\SetSymbolFont{stmry}{bold}{U}{stmry}{b}{n}

% Declare specific arrows from txfonts without loading the full package
\makeatletter
\def\re@DeclareMathSymbol#1#2#3#4{%
    \let#1=\undefined
    \DeclareMathSymbol{#1}{#2}{#3}{#4}}
\re@DeclareMathSymbol{\neArrow}{\mathrel}{symbolsC}{116}
\re@DeclareMathSymbol{\neArr}{\mathrel}{symbolsC}{116}
\re@DeclareMathSymbol{\seArrow}{\mathrel}{symbolsC}{117}
\re@DeclareMathSymbol{\seArr}{\mathrel}{symbolsC}{117}
\re@DeclareMathSymbol{\nwArrow}{\mathrel}{symbolsC}{118}
\re@DeclareMathSymbol{\nwArr}{\mathrel}{symbolsC}{118}
\re@DeclareMathSymbol{\swArrow}{\mathrel}{symbolsC}{119}
\re@DeclareMathSymbol{\swArr}{\mathrel}{symbolsC}{119}
\re@DeclareMathSymbol{\nequiv}{\mathrel}{symbolsC}{46}
\re@DeclareMathSymbol{\Perp}{\mathrel}{symbolsC}{121}
\re@DeclareMathSymbol{\Vbar}{\mathrel}{symbolsC}{121}
\re@DeclareMathSymbol{\sslash}{\mathrel}{stmry}{12}
\re@DeclareMathSymbol{\invamp}{\mathrel}{symbolsC}{77}
\re@DeclareMathSymbol{\parr}{\mathrel}{symbolsC}{77}
\makeatother

% Widecheck
\makeatletter
\DeclareRobustCommand\widecheck[1]{{\mathpalette\@widecheck{#1}}}
\def\@widecheck#1#2{%
    \setbox\z@\hbox{\m@th$#1#2$}%
    \setbox\tw@\hbox{\m@th$#1%
       \widehat{%
          \vrule\@width\z@\@height\ht\z@
          \vrule\@height\z@\@width\wd\z@}$}%
    \dp\tw@-\ht\z@
    \@tempdima\ht\z@ \advance\@tempdima2\ht\tw@ \divide\@tempdima\thr@@
    \setbox\tw@\hbox{%
       \raise\@tempdima\hbox{\scalebox{1}[-1]{\lower\@tempdima\box
\tw@}}}%
    {\ooalign{\box\tw@ \cr \box\z@}}}
\makeatother

% udots (taken from yhmath)
\makeatletter
\def\udots{\mathinner{\mkern2mu\raise\p@\hbox{.}
\mkern2mu\raise4\p@\hbox{.}\mkern1mu
\raise7\p@\vbox{\kern7\p@\hbox{.}}\mkern1mu}}
\makeatother

%% Renaming existing commands
\newcommand{\underoverset}[3]{\underset{#1}{\overset{#2}{#3}}}
\newcommand{\widevec}{\overrightarrow}
\newcommand{\darr}{\downarrow}
\newcommand{\nearr}{\nearrow}
\newcommand{\nwarr}{\nwarrow}
\newcommand{\searr}{\searrow}
\newcommand{\swarr}{\swarrow}
\newcommand{\curvearrowbotright}{\curvearrowright}
\newcommand{\uparr}{\uparrow}
\newcommand{\downuparrow}{\updownarrow}
\newcommand{\duparr}{\updownarrow}
\newcommand{\updarr}{\updownarrow}
\newcommand{\gt}{>}
\newcommand{\lt}{<}
\newcommand{\map}{\mapsto}
\newcommand{\embedsin}{\hookrightarrow}
\newcommand{\Alpha}{A}
\newcommand{\Beta}{B}
\newcommand{\Zeta}{Z}
\newcommand{\Eta}{H}
\newcommand{\Iota}{I}
\newcommand{\Kappa}{K}
\newcommand{\Mu}{M}
\newcommand{\Nu}{N}
\newcommand{\Rho}{P}
\newcommand{\Tau}{T}
\newcommand{\Upsi}{\Upsilon}
\newcommand{\omicron}{o}
\newcommand{\lang}{\langle}
\newcommand{\rang}{\rangle}
\newcommand{\Union}{\bigcup}
\newcommand{\Intersection}{\bigcap}
\newcommand{\Oplus}{\bigoplus}
\newcommand{\Otimes}{\bigotimes}
\newcommand{\Wedge}{\bigwedge}
\newcommand{\Vee}{\bigvee}
\newcommand{\coproduct}{\coprod}
\newcommand{\product}{\prod}
\newcommand{\closure}{\overline}
\newcommand{\integral}{\int}
\newcommand{\doubleintegral}{\iint}
\newcommand{\tripleintegral}{\iiint}
\newcommand{\quadrupleintegral}{\iiiint}
\newcommand{\conint}{\oint}
\newcommand{\contourintegral}{\oint}
\newcommand{\infinity}{\infty}
\renewcommand{\empty}{\emptyset}
\newcommand{\bottom}{\bot}
\newcommand{\minusb}{\boxminus}
\newcommand{\plusb}{\boxplus}
\newcommand{\timesb}{\boxtimes}
\newcommand{\intersection}{\cap}
\newcommand{\union}{\cup}
\newcommand{\Del}{\nabla}
\newcommand{\odash}{\circleddash}
\newcommand{\negspace}{\\\!}
\newcommand{\widebar}{\overline}
\newcommand{\textsize}{\normalsize}
\renewcommand{\scriptsize}{\scriptstyle}
\newcommand{\scriptscriptsize}{\scriptscriptstyle}
\newcommand{\mathfr}{\mathfrak}
\newcommand{\statusline}[2]{#2}
\newcommand{\toggle}[2]{#1}

% Theorem Environments
\theoremstyle{plain}
\newtheorem{theorem}{Theorem}
\newtheorem{lemma}{Lemma}
\newtheorem{prop}{Proposition}
\newtheorem{cor}{Corollary}
\newtheorem*{utheorem}{Theorem}
\newtheorem*{ulemma}{Lemma}
\newtheorem*{uprop}{Proposition}
\newtheorem*{ucor}{Corollary}
\theoremstyle{definition}
\newtheorem{defn}{Definition}
\newtheorem{example}{Example}
\newtheorem*{udefn}{Definition}
\newtheorem*{uexample}{Example}
\theoremstyle{remark}
\newtheorem{remark}{Remark}
\newtheorem{note}{Note}
\newtheorem*{uremark}{Remark}
\newtheorem*{unote}{Note}

%-------------------------------------------------------------------

\begin{document}

%-------------------------------------------------------------------

!
  end
  
  def test_tex
    r = process('tex', 'web' => 'wiki1', 'id' => 'HomePage')
    assert_response(:success)
    
    assert_equal @tex_header1 + @tex_header2 + %q!\section*{HomePage}

HisWay would be MyWay $\sin(x) \includegraphics[width=3em]{foo}$ in kinda ThatWay in HisWay though MyWay $\backslash$OverThere --{} see SmartEngine in that SmartEngineGUI



\end{document}
!, r.body
  end

  def test_tex_with_blackboard_digits
    @wiki.write_page('wiki1', 'Page2',
        "Page2 contents $\\mathbb{01234}$.\n",
        Time.now, Author.new('AnotherAuthor', '127.0.0.2'), test_renderer)
    r = process('tex', 'web' => 'wiki1', 'id' => 'Page2')
    assert_response(:success)
    
    assert_equal @tex_header1 + "\\usepackage{mathbbol}\n" + @tex_header2 + %q!\section*{Page2}

Page2 contents $\mathbb{01234}$.



\end{document}
!, r.body
  end

  def test_web_list
    another_wiki = @wiki.create_web('Another Wiki', 'another_wiki')
    
    r = process('web_list')
    
    assert_response(:success)
    assert_equal [another_wiki, webs(:instiki), @web], r.template_objects['webs']
  end
  
end
