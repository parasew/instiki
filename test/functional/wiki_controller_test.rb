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

class WikiControllerTest < Test::Unit::TestCase
  fixtures :webs, :pages, :revisions, :system, :wiki_references
  
  def setup
    @controller = WikiController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @wiki = Wiki.new
    @web = webs(:test_wiki)
    @home = @page = pages(:home_page)
    @oak = pages(:oak)
    @elephant = pages(:elephant)
  end

  def test_authenticate
    set_web_property :password, 'pswd'
  
    get :authenticate, :web => 'wiki1', :password => 'pswd'
    assert_redirected_to :web => 'wiki1', :action => 'show', :id => 'HomePage'
    assert_equal ['pswd'], @response.cookies['web_address']
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

    assert_success
    assert_equal %w(AnAuthor BreakingTheOrder DavidHeinemeierHansson Guest Me TreeHugger), 
        r.template_objects['authors']
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
    assert_success
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
    assert_success
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
    assert_success
    xml = REXML::Document.new(r.body)
    form = REXML::XPath.first(xml, '//form')
    assert_equal '/wiki1/save/With+%3A+Special+%2F%3E+symbols', form.attributes['action']
  end

  def test_export_html
    # rollback homepage to a version that is easier to match
    @home.rollback(0, Time.now, 'Rick', test_renderer)
    r = process 'export_html', 'web' => 'wiki1'
    
    assert_success(bypass_body_parsing = true)
    assert_equal 'application/zip', r.headers['Content-Type']
    assert_match /attachment; filename="wiki1-html-\d\d\d\d-\d\d-\d\d-\d\d-\d\d-\d\d.zip"/, 
        r.headers['Content-Disposition']
    assert_equal 'PK', r.body[0..1], 'Content is not a zip file'
    assert_equal :export, r.template_objects['link_mode']
    
    # Tempfile doesn't know how to open files with binary flag, hence the two-step process
    Tempfile.open('instiki_export_file') { |f| @tempfile_path = f.path }
    begin 
      File.open(@tempfile_path, 'wb') { |f| f.write(r.body); @exported_file = f.path }
      Zip::ZipFile.open(@exported_file) do |zip| 
        assert_equal %w(Elephant.html FirstPage.html HomePage.html MyWay.html NoWikiWord.html Oak.html SmartEngine.html ThatWay.html index.html), zip.dir.entries('.').sort
        assert_match /.*<html .*All about elephants.*<\/html>/, 
            zip.file.read('Elephant.html').gsub(/\s+/, ' ')
        assert_match /.*<html .*All about oak.*<\/html>/, 
            zip.file.read('Oak.html').gsub(/\s+/, ' ')
        assert_match /.*<html .*First revision of the.*HomePage.*end.*<\/html>/, 
            zip.file.read('HomePage.html').gsub(/\s+/, ' ')
        assert_equal '<html><head><META HTTP-EQUIV="Refresh" CONTENT="0;URL=HomePage.html"></head></html> ', zip.file.read('index.html').gsub(/\s+/, ' ')
      end
    ensure
      File.delete(@tempfile_path) if File.exist?(@tempfile_path)
    end
  end

  def test_export_html_no_layout    
    r = process 'export_html', 'web' => 'wiki1', 'layout' => 'no'
    
    assert_success(bypass_body_parsing = true)
    assert_equal 'application/zip', r.headers['Content-Type']
    assert_match /attachment; filename="wiki1-html-\d\d\d\d-\d\d-\d\d-\d\d-\d\d-\d\d.zip"/, 
        r.headers['Content-Disposition']
    assert_equal 'PK', r.body[0..1], 'Content is not a zip file'
    assert_equal :export, r.template_objects['link_mode']
  end

  def test_export_markup
    r = process 'export_markup', 'web' => 'wiki1'

    assert_success(bypass_body_parsing = true)
    assert_equal 'application/zip', r.headers['Content-Type']
    assert_match /attachment; filename="wiki1-textile-\d\d\d\d-\d\d-\d\d-\d\d-\d\d-\d\d.zip"/, 
        r.headers['Content-Disposition']
    assert_equal 'PK', r.body[0..1], 'Content is not a zip file'
  end


  if ENV['INSTIKI_TEST_LATEX'] or defined? $INSTIKI_TEST_PDFLATEX

    def test_export_pdf
      r = process 'export_pdf', 'web' => 'wiki1'
      assert_success(bypass_body_parsing = true)
      assert_equal 'application/pdf', r.headers['Content-Type']
      assert_match /attachment; filename="wiki1-tex-\d\d\d\d-\d\d-\d\d-\d\d-\d\d-\d\d.pdf"/, 
          r.headers['Content-Disposition']
      assert_equal '%PDF', r.body[0..3]
      assert_equal "EOF\n", r.body[-4..-1]
    end

  else
    puts 'Warning: tests involving pdflatex are very slow, therefore they are disabled by default.'
    puts '         Set environment variable INSTIKI_TEST_PDFLATEX or global Ruby variable'
    puts '         $INSTIKI_TEST_PDFLATEX to enable them.'
  end
  
  def test_export_tex    
    r = process 'export_tex', 'web' => 'wiki1'

    assert_success(bypass_body_parsing = true)
    assert_equal 'application/octet-stream', r.headers['Content-Type']
    assert_match /attachment; filename="wiki1-tex-\d\d\d\d-\d\d-\d\d-\d\d-\d\d-\d\d.tex"/, 
        r.headers['Content-Disposition']
    assert_equal '\documentclass', r.body[0..13], 'Content is not a TeX file'
  end

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
    assert_equal [@elephant, pages(:first_page), @home, pages(:my_way), pages(:no_wiki_word), @oak, pages(:smart_engine), pages(:that_way)], r.template_objects['pages_in_category']
  end


  def test_locked
    @home.lock(Time.now, 'Locky')
    r = process('locked', 'web' => 'wiki1', 'id' => 'HomePage')
    assert_success
    assert_equal @home, r.template_objects['page']
  end


  def test_login
    r = process 'login', 'web' => 'wiki1'
    assert_success
    # this action goes straight to the templates
  end


  def test_new
    r = process('new', 'id' => 'NewPage', 'web' => 'wiki1')
    assert_success
    assert_equal 'AnonymousCoward', r.template_objects['author']
    assert_equal 'NewPage', r.template_objects['page_name']
  end


  if ENV['INSTIKI_TEST_LATEX'] or defined? $INSTIKI_TEST_PDFLATEX

    def test_pdf
      assert RedClothForTex.available?, 'Cannot do test_pdf when pdflatex is not available'
      r = process('pdf', 'web' => 'wiki1', 'id' => 'HomePage')
      assert_success(bypass_body_parsing = true)

      assert_equal '%PDF', r.body[0..3]
      assert_equal "EOF\n", r.body[-4..-1]

      assert_equal 'application/pdf', r.headers['Content-Type']
      assert_match /attachment; filename="HomePage-wiki1-\d\d\d\d-\d\d-\d\d-\d\d-\d\d-\d\d.pdf"/, 
          r.headers['Content-Disposition']
    end

  end


  def test_print
    r = process('print', 'web' => 'wiki1', 'id' => 'HomePage')

    assert_success
    assert_equal :show, r.template_objects['link_mode']
  end


  def test_published
    set_web_property :published, true
    
    r = process('published', 'web' => 'wiki1', 'id' => 'HomePage')
    
    assert_success
    assert_equal @home, r.template_objects['page']
  end


  def test_published_web_not_published
    set_web_property :published, false
    
    r = process('published', 'web' => 'wiki1', 'id' => 'HomePage')

    assert_redirected_to :action => 'show', :id => 'HomePage'    
  end


  def test_recently_revised
    r = process('recently_revised', 'web' => 'wiki1')
    assert_success
    
    assert_equal %w(animals trees), r.template_objects['categories']
    assert_nil r.template_objects['category']
    assert_equal [@elephant, pages(:first_page), @home, pages(:my_way), pages(:no_wiki_word), @oak, pages(:smart_engine), pages(:that_way)], r.template_objects['pages_in_category']
    assert_equal 'the web', r.template_objects['set_name']
  end
  
  def test_recently_revised_with_categorized_page
    page2 = @wiki.write_page('wiki1', 'Page2',
        "Page2 contents.\n" +
        "category: categorized", 
        Time.now, Author.new('AnotherAuthor', '127.0.0.2'), test_renderer)
      
    r = process('recently_revised', 'web' => 'wiki1')
    assert_success
    
    assert_equal %w(animals categorized trees), r.template_objects['categories']
    # no category is specified in params
    assert_nil r.template_objects['category']
    assert_equal [@elephant, pages(:first_page), @home, pages(:my_way), pages(:no_wiki_word), @oak, page2, pages(:smart_engine), pages(:that_way)], r.template_objects['pages_in_category'],
        "Pages are not as expected: " +
        r.template_objects['pages_in_category'].map {|p| p.name}.inspect
    assert_equal 'the web', r.template_objects['set_name']
  end

  def test_recently_revised_with_categorized_page_multiple_categories
    r = process('recently_revised', 'web' => 'wiki1')
    assert_success

    assert_equal ['animals', 'trees'], r.template_objects['categories']
    # no category is specified in params
    assert_nil r.template_objects['category']
    assert_equal [@elephant, pages(:first_page), @home, pages(:my_way), pages(:no_wiki_word), @oak, pages(:smart_engine), pages(:that_way)], r.template_objects['pages_in_category'], 
        "Pages are not as expected: " +
        r.template_objects['pages_in_category'].map {|p| p.name}.inspect
    assert_equal 'the web', r.template_objects['set_name']
  end

  def test_recently_revised_with_specified_category
    r = process('recently_revised', 'web' => 'wiki1', 'category' => 'animals')
    assert_success
    
    assert_equal ['animals', 'trees'], r.template_objects['categories']
    # no category is specified in params
    assert_equal 'animals', r.template_objects['category']
    assert_equal [@elephant], r.template_objects['pages_in_category']
    assert_equal "category 'animals'", r.template_objects['set_name']
  end


  def test_revision
    r = process 'revision', 'web' => 'wiki1', 'id' => 'HomePage', 'rev' => '0'

    assert_success
    assert_equal @home, r.template_objects['page']
    assert_equal @home.revisions[0], r.template_objects['revision'] 
  end
  

  def test_rollback
    # rollback shows a form where a revision can be edited.
    # its assigns the same as or revision
    r = process 'rollback', 'web' => 'wiki1', 'id' => 'HomePage', 'rev' => '0'

    assert_success
    assert_equal @home, r.template_objects['page']
    assert_equal @home.revisions[0], r.template_objects['revision']
  end

  def test_rss_with_content
    r = process 'rss_with_content', 'web' => 'wiki1'

    assert_success
    pages = r.template_objects['pages_by_revision']
    assert_equal [@elephant, @oak, pages(:no_wiki_word), pages(:that_way), pages(:smart_engine), pages(:my_way), pages(:first_page), @home], pages,
        "Pages are not as expected: #{pages.map {|p| p.name}.inspect}"
    assert !r.template_objects['hide_description']
  end

  def test_rss_with_content_when_blocked
    @web.update_attributes(:password => 'aaa', :published => false)
    @web = Web.find(@web.id)
    
    r = process 'rss_with_content', 'web' => 'wiki1'
    
    assert_equal 403, r.response_code
  end
  

  def test_rss_with_headlines
    @title_with_spaces = @wiki.write_page('wiki1', 'Title With Spaces', 
      'About spaces', 1.hour.ago, Author.new('TreeHugger', '127.0.0.2'), test_renderer)
    
    @request.host = 'localhost'
    @request.port = 8080
  
    r = process 'rss_with_headlines', 'web' => 'wiki1'

    assert_success
    pages = r.template_objects['pages_by_revision']
    assert_equal [@elephant, @title_with_spaces, @oak, pages(:no_wiki_word), pages(:that_way), pages(:smart_engine), pages(:my_way), pages(:first_page), @home], pages, "Pages are not as expected: #{pages.map {|p| p.name}.inspect}"
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

    assert_template_xpath_match '/rss/channel/link', 
        'http://localhost:8080/wiki1/show/HomePage'
    assert_template_xpath_match '/rss/channel/item/guid', expected_page_links
    assert_template_xpath_match '/rss/channel/item/link', expected_page_links
  end

  def test_rss_switch_links_to_published
    @web.update_attributes(:password => 'aaa', :published => true)
    @web = Web.find(@web.id)
    
    @request.host = 'foo.bar.info'
    @request.port = 80

    r = process 'rss_with_headlines', 'web' => 'wiki1'

    assert_success
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
    
    assert_template_xpath_match '/rss/channel/link', 
        'http://foo.bar.info/wiki1/published/HomePage'
    assert_template_xpath_match '/rss/channel/item/guid', expected_page_links
    assert_template_xpath_match '/rss/channel/item/link', expected_page_links
  end

  def test_rss_with_params
    setup_wiki_with_30_pages

    r = process 'rss_with_headlines', 'web' => 'wiki1'
    assert_success
    pages = r.template_objects['pages_by_revision']
    assert_equal 15, pages.size, 15
    
    r = process 'rss_with_headlines', 'web' => 'wiki1', 'limit' => '5'
    assert_success
    pages = r.template_objects['pages_by_revision']
    assert_equal 5, pages.size
    
    r = process 'rss_with_headlines', 'web' => 'wiki1', 'limit' => '25'
    assert_success
    pages = r.template_objects['pages_by_revision']
    assert_equal 25, pages.size
    
    r = process 'rss_with_headlines', 'web' => 'wiki1', 'limit' => 'all'
    assert_success
    pages = r.template_objects['pages_by_revision']
    assert_equal 38, pages.size
    
    r = process 'rss_with_headlines', 'web' => 'wiki1', 'start' => '1976-10-16'
    assert_success
    pages = r.template_objects['pages_by_revision']
    assert_equal 23, pages.size
    
    r = process 'rss_with_headlines', 'web' => 'wiki1', 'end' => '1976-10-16'
    assert_success
    pages = r.template_objects['pages_by_revision']
    assert_equal 15, pages.size
    
    r = process 'rss_with_headlines', 'web' => 'wiki1', 'start' => '1976-10-01', 'end' => '1976-10-06'
    assert_success
    pages = r.template_objects['pages_by_revision']
    assert_equal 5, pages.size
  end

  def test_rss_title_with_ampersand
    # was ticket:143    
    @wiki.write_page('wiki1', 'Title&With&Ampersands', 
      'About spaces', 1.hour.ago, Author.new('NitPicker', '127.0.0.3'), test_renderer)

    r = process 'rss_with_headlines', 'web' => 'wiki1'

    assert r.body.include?('<title>Home Page</title>')
    assert r.body.include?('<title>Title&amp;With&amp;Ampersands</title>')
  end

  def test_rss_timestamp    
    new_page = @wiki.write_page('wiki1', 'PageCreatedAtTheBeginningOfCtime', 
      'Created on 1 Jan 1970 at 0:00:00 Z', Time.at(0), Author.new('NitPicker', '127.0.0.3'),
      test_renderer)

    r = process 'rss_with_headlines', 'web' => 'wiki1'
    assert_template_xpath_match '/rss/channel/item/pubDate[9]', "Thu, 01 Jan 1970 00:00:00 Z"
  end
  
  def test_save
    r = process 'save', 'web' => 'wiki1', 'id' => 'NewPage', 'content' => 'Contents of a new page', 
      'author' => 'AuthorOfNewPage'
    
    assert_redirected_to :web => 'wiki1', :action => 'show', :id => 'NewPage'
    assert_equal ['AuthorOfNewPage'], r.cookies['author'].value
    new_page = @wiki.read_page('wiki1', 'NewPage')
    assert_equal 'Contents of a new page', new_page.content
    assert_equal 'AuthorOfNewPage', new_page.author
  end

  def test_save_new_revision_of_existing_page
    @home.lock(Time.now, 'Batman')
    current_revisions = @home.revisions.size

    r = process 'save', 'web' => 'wiki1', 'id' => 'HomePage', 'content' => 'Revised HomePage', 
      'author' => 'Batman'

    assert_redirected_to :web => 'wiki1', :action => 'show', :id => 'HomePage'
    assert_equal ['Batman'], r.cookies['author'].value
    home_page = @wiki.read_page('wiki1', 'HomePage')
    assert_equal current_revisions+1, home_page.revisions.size
    assert_equal 'Revised HomePage', home_page.content
    assert_equal 'Batman', home_page.author
    assert !home_page.locked?(Time.now)
  end

  def test_save_new_revision_identical_to_last
    revisions_before = @home.revisions.size
    @home.lock(Time.now, 'AnAuthor')
  
    r = process 'save', {'web' => 'wiki1', 'id' => 'HomePage', 
        'content' => @home.revisions.last.content.dup, 
        'author' => 'SomeOtherAuthor'}, {:return_to => '/wiki1/show/HomePage'}

    assert_redirected_to :action => 'edit', :web => 'wiki1', :id => 'HomePage'
    assert_flash_has :error
    assert r.flash[:error].kind_of?(Instiki::ValidationError)

    revisions_after = @home.revisions.size
    assert_equal revisions_before, revisions_after
    @home = Page.find(@home.id)
    assert !@home.locked?(Time.now), 'HomePage should be unlocked if an edit was unsuccessful'
  end


  def test_search
    r = process 'search', 'web' => 'wiki1', 'query' => '\s[A-Z]ak'
    
    assert_redirected_to :action => 'show', :id => 'Oak'
  end

  def test_search_multiple_results
    r = process 'search', 'web' => 'wiki1', 'query' => 'All about'
    
    assert_success
    assert_equal 'All about', r.template_objects['query']
    assert_equal [@elephant, @oak], r.template_objects['results']
    assert_equal [], r.template_objects['title_results']
  end

  def test_search_by_content_and_title
    r = process 'search', 'web' => 'wiki1', 'query' => '(Oak|Elephant)'
    
    assert_success
    assert_equal '(Oak|Elephant)', r.template_objects['query']
    assert_equal [@elephant, @oak], r.template_objects['results']
    assert_equal [@elephant, @oak], r.template_objects['title_results']
  end

  def test_search_zero_results
    r = process 'search', 'web' => 'wiki1', 'query' => 'non-existant text'
    
    assert_success
    assert_equal [], r.template_objects['results']
    assert_equal [], r.template_objects['title_results']
  end

  def test_show_page
    r = process('show', 'id' => 'Oak', 'web' => 'wiki1')
    assert_success
    assert_tag :content => /All about oak/
  end

  def test_show_page_with_multiple_revisions
    @wiki.write_page('wiki1', 'HomePage', 'Second revision of the HomePage end', Time.now, 
        Author.new('AnotherAuthor', '127.0.0.2'), test_renderer)

    r = process('show', 'id' => 'HomePage', 'web' => 'wiki1')

    assert_success
    assert_match /Second revision of the <a.*HomePage.*<\/a> end/, r.body
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


  def test_tex
    r = process('tex', 'web' => 'wiki1', 'id' => 'HomePage')
    assert_success
    
    assert_equal "\\documentclass[12pt,titlepage]{article}\n\n\\usepackage[danish]{babel}      " +
        "%danske tekster\n\\usepackage[OT1]{fontenc}       %rigtige danske bogstaver...\n" +
        "\\usepackage{a4}\n\\usepackage{graphicx}\n\\usepackage{ucs}\n\\usepackage[utf8x]" +
        "{inputenc}\n\\input epsf \n\n%----------------------------------------------------" +
        "---------------\n\n\\begin{document}\n\n\\sloppy\n\n%-----------------------------" +
        "--------------------------------------\n\n\\section*{HomePage}\n\nHisWay would be " +
        "MyWay in kinda ThatWay in HisWay though MyWay \\OverThere -- see SmartEngine in that " +
        "SmartEngineGUI\n\n\\end{document}", r.body
  end


  def test_web_list
    another_wiki = @wiki.create_web('Another Wiki', 'another_wiki')
    
    r = process('web_list')
    
    assert_success
    assert_equal [another_wiki, webs(:instiki), @web], r.template_objects['webs']
  end
  
end
