require 'fileutils'
require 'cgi'
require 'test/unit'
require 'rexml/document'

INSTIKI_ROOT = File.expand_path(File.dirname(__FILE__) + "/../..")
require(File.expand_path(File.dirname(__FILE__) + "/../../config/environment"))

# TODO Create tests for:
# * exporting HTML
# * exporting markup
# * include tag

# Use instiki/../watir, if such a directory exists; This can be a CVS HEAD version of Watir. 
# Otherwise Watir has to be installed in ruby/lib.
$:.unshift INSTIKI_ROOT + '/../watir' if File.exists?(INSTIKI_ROOT + '/../watir/watir.rb')
require 'watir'

INSTIKI_PORT = 2501
HOME = "http://localhost:#{INSTIKI_PORT}"

class E2EInstikiTest < Test::Unit::TestCase

  def startup
    @@instiki = InstikiController.start

    sleep 8
    @@ie = Watir::IE.start(HOME)
    @@ie.set_fast_speed if (ARGV & ['-d', '--demo', '-demo', 'demo']).empty?

    setup_web
    setup_home_page

    @@ie
  end

  def self.shutdown  
    @@ie.close if defined? @@ie
    @@instiki.stop
  end
  
  def ie
    if defined? @@ie
      @@ie
    else
      startup
    end
  end

  def setup
    ie.goto HOME
    ie
  end

  # Numbers like _00010_ determine the sequence in which the test cases are executed by Test::Unit
  # Unfortunately, this sequence is important.

  def test_00010_home_page_contents
    check_main_menu
    check_bottom_menu
    check_footnote
  end
  
  def test_00020_add_a_page
    # Add reference to a non-existant wiki page
    enter_markup('HomePage', '[[Another Wiki Page]]')
    assert_equal '?', ie.link(:url, url(:new, 'Another Wiki Page')).text
    
    # Edit the first revision of a page
    enter_markup('Another Wiki Page', 'First revision of Another Wiki Page, linked from HomePage')

    # Check contents of the new page
    assert_equal url(:show, 'Another Wiki Page'), ie.url
    assert_match /First revision of Another Wiki Page, linked from Home Page/, ie.text
    assert_match /Linked from: Home Page/, ie.text

    # There must be three links to HomePage - main menu, contents of the page and navigation bar
    links_to_homepage = ie.links.to_a.select { |link| link.text == 'Home Page' }
    assert_equal 3, links_to_homepage.size
    links_to_homepage.each { |link| assert_equal url(:show, 'HomePage'), link.href }

    # Check also the "created on ... by ..." footnote
    assert_match Regexp.new('Created on ' + date_pattern + ' by Anonymous Coward\?'), ie.text
  end
  
  def test_00030_edit_page
    enter_markup('TestEditPage', 'Test Edit Page, revision 1')
    assert_match /Test Edit Page, revision 1/, ie.text

    # subsequent revision by the anonymous author
    enter_markup('TestEditPage', 'Test Edit Page, revision 1, altered')
    assert_match /Test Edit Page, revision 1, altered/, ie.text
    assert_match Regexp.new('Created on ' + date_pattern + ' by Anonymous Coward\?'), ie.text
    
    # revision by a named author
    enter_markup('TestEditPage', 'Test Edit Page, revision 2', 'Author')
    assert_match /Test Edit Page, revision 2/, ie.text
    assert_match Regexp.new('Revised on ' + date_pattern + ' by Author\?'), ie.text

    link_to_previous_revision = ie.link(:name, 'to_previous_revision')
    assert_equal url(:revision, 'TestEditPage', 1), link_to_previous_revision.href
    assert_equal 'Back in time', link_to_previous_revision.text
    assert_match /Edit \| Back in time \(1 revision\) \| See changes/, ie.text
    
    # another anonymous revision
    enter_markup('TestEditPage', 'Test Edit Page, revision 3')
    assert_match /Test Edit Page, revision 3/, ie.text
    assert_match /Edit \| Back in time \(2 revisions\) \| See changes /, ie.text
  end

  def test_00040_traversing_revisions
    ie.goto url(:revision, 'TestEditPage', 2)
    assert_match /Test Edit Page, revision 2/, ie.text
    assert_match(Regexp.new(
        'Forward in time \(to current\) \| Back in time \(1 more\) \| See current \| See changes \| Rollback'),
        ie.text)

    ie.link(:name, 'to_previous_revision').click
    assert_match /Test Edit Page, revision 1, altered/, ie.text
    assert_match /Forward in time \(2 more\) \| See current \| Rollback/, ie.text

    ie.link(:name, 'to_next_revision').click
    assert_match /Test Edit Page, revision 2/, ie.text

    ie.link(:name, 'to_next_revision').click
    assert_match /Test Edit Page, revision 3/, ie.text
  end

  def test_00050_rollback
    ie.goto url(:revision, 'TestEditPage', 2)
    assert_match /Test Edit Page, revision 2/, ie.text
    ie.link(:name, 'rollback').click
    assert_equal url(:rollback, 'TestEditPage', 2), ie.url
    assert_equal 'Test Edit Page, revision 2', ie.text_field(:name, 'content').value
    
    ie.text_field(:name, 'content').set('Test Edit Page, revision 2, rolled back')
    ie.button(:value, 'Update').click
    
    assert_equal url(:show, 'TestEditPage'), ie.url
    assert_match /Test Edit Page, revision 2, rolled back/, ie.text
  end

  def test_0060_see_changes
    ie.goto url(:show, 'TestEditPage')

    assert_match /Test Edit Page, revision 2, rolled back/, ie.text

    ie.link(:text, 'See changes').click

    assert_match /Showing changes from revision #2 to #3: Added \| Removed/, ie.text
    assert_match /Test Edit Page, revision 22, rolled back/, ie.text
    
    ie.link(:text, 'Hide changes').click
    
    assert_match /Test Edit Page, revision 2, rolled back/, ie.text
  end

  def test_0070_all_pages
    # create a wanted page, and unlink Another Wiki Page from Home Page 
    # (to see that it doesn't show up in the orphans, regardless)
    enter_markup('Another Wiki Page', 'Reference to a NonExistantPage')
  
    ie.link(:text, 'All Pages').click

    page_links = ie.links.map { |l| l.text }
    expected_page_links = ['Another Wiki Page', 'Home Page', 'Test Edit Page', '?', 
                           'Another Wiki Page', 'Test Edit Page']
    assert_equal expected_page_links, page_links[-6..-1]
    links_sequence = 
        'All Pages.*Another Wiki Page.*Home Page.*Test Edit Page.*' + 
        'Wanted Pages.*Non Existant Page\? wanted by Another Wiki Page.*'+
        'Orphaned Pages.*Test Edit Page.*'
    assert_match Regexp.new(links_sequence, Regexp::MULTILINE), ie.text
    # and before that, we have the tail of the main menu


require 'breakpoint'; breakpoint


    assert_equal 'Export', page_links[-7]
  end

  def test_0080_recently_revised
    ie.link(:text, 'Recently Revised').click
  
    links = ie.links.map { |l| l.text }
    assert_equal ['Another Wiki Page', '?', 'Test Edit Page', '?', 'Home Page', '?'], links[-6..-1]  
    
    expected_text = 
        'Another Wiki Page.*by Anonymous Coward\?.*' +
        'Test Edit Page.*by Anonymous Coward\?.*' +
        'Home Page.*by Anonymous Coward\?.*'
    assert_match Regexp.new(expected_text, Regexp::MULTILINE), ie.text
  end
  
  def test_0090_authors
    # create a revision of TestEditPage, and a corresponding author page
    enter_markup('TestEditPage', '3rd revision of this page', 'Another Author')
    ie.link(:afterText, 'Another Author').click
    assert_equal url(:new, 'Another Author'), ie.url
    enter_markup('Another Author',  'Email me at another_author@foo.bar.com', 'Another Author')

    ie.link(:text, 'Authors').click

    expected_authors = 
        'Anonymous Coward\? co- or authored: Another Wiki Page, Home Page, Test Edit Page.*' +
        'Another Author co- or authored: Another Author, Test Edit Page.*' +
        'Author\? co- or authored: Test Edit Page'
    assert_match Regexp.new(expected_authors, Regexp::MULTILINE), ie.text

    ie.link(:text, 'Another Author').click
    assert_equal url(:show, 'Another Author'), ie.url
    ie.back
    ie.link(:text, 'Test Edit Page').click
    assert_equal url(:show, 'TestEditPage'), ie.url
  end

  def test_0100_feeds
    ie.link(:text, 'Feeds').click
    assert_equal url(:rss_with_content), ie.link(:text, 'Full content (RSS 2.0)').href
    assert_equal url(:rss_with_headlines), ie.link(:text, 'Headlines (RSS 2.0)').href
    
    ie.link(:text, 'Full content (RSS 2.0)').click
    assert_nothing_raised { REXML::Document.new ie.text }

    ie.back
    ie.link(:text, 'Headlines (RSS 2.0)').click
    assert_nothing_raised { REXML::Document.new ie.text }
  end

  private

  def bp
    require 'breakpoint'
    breakpoint
  end

  def check_main_menu
    assert_equal HOME + '/wiki/list', ie.link(:text, 'All Pages').href
    assert_equal HOME + '/wiki/recently_revised', ie.link(:text, 'Recently Revised').href
    assert_equal HOME + '/wiki/authors', ie.link(:text, 'Authors').href
    assert_equal HOME + '/wiki/feeds', ie.link(:text, 'Feeds').href
    assert_equal HOME + '/wiki/export', ie.link(:text, 'Export').href
  end

  def check_bottom_menu
    assert_equal url(:edit, 'HomePage'), ie.link(:text, 'Edit Page').href
    assert_equal HOME + '/wiki/edit_web', ie.link(:text, 'Edit Web').href
    assert_equal url(:print, 'HomePage'), ie.link(:text, 'Print').href
  end

  def check_footnote
    assert_match /This site is running on Instiki/, ie.text
    assert_equal 'http://instiki.org/', ie.link(:text, 'Instiki').href
    assert_match /Powered by Ruby on Rails/, ie.text
    assert_equal 'http://rubyonrails.com/', ie.link(:text, 'Ruby on Rails').href
  end

  def date_pattern
    '(January|February|March|April|May|June|July|August|September|October|November|December) ' + 
        '\d\d?, \d\d\d\d \d\d:\d\d:\d\d'
  end

  def enter_markup(page, content, author = nil)
    ie.goto url(:show, page)
    if ie.url == url(:show, page)
      ie.link(:name, 'edit').click
      assert_equal url(:edit, page), ie.url
    else
      assert_equal url(:new, page), ie.url
    end

    ie.text_field(:name, 'content').set(content)
    ie.text_field(:name, 'author').set(author || '')
    ie.button(:value, 'Submit').click

    assert_equal url(:show, page), ie.url
  end

  def setup_web
    assert_equal 'Wiki', ie.text_field(:name, 'web_name').value
    assert_equal 'wiki', ie.text_field(:name, 'web_address').value
    assert_equal '', ie.text_field(:name, 'password').value
    assert_equal '', ie.text_field(:name, 'password_check').value
    
    ie.text_field(:name, 'password').set('123')
    ie.text_field(:name, 'password_check').set('123')
    ie.button(:value, 'Setup').click
    assert_equal url(:new, 'HomePage'), ie.url
  end

  def setup_home_page
    ie.text_field(:name, 'content').set('Homepage of a test wiki')
    ie.button(:value, 'Submit').click
    assert_equal url(:show, 'HomePage'), ie.url
  end

  def url(operation, page_name = nil, revision = nil)
    page_name = CGI.escape(page_name) if page_name
    case operation
    when :edit, :new, :show, :print, :revision, :rollback
      "#{HOME}/wiki/#{operation}/#{page_name}" + (revision ? "?rev=#{revision}" : '')
    when :rss_with_content, :rss_with_headlines
      "#{HOME}/wiki/#{operation}"
    else
      raise "Unsupported operation: '#{operation}"
    end
  end

end

class InstikiController

  attr_reader :process_id

  def self.start
    startup_info = [68].pack('lx64')
    process_info = [0, 0, 0, 0].pack('llll')

    clear_database
    startup_command =
        "ruby #{RAILS_ROOT}/instiki.rb --port #{INSTIKI_PORT} --environment development"

    result = Win32API.new('kernel32.dll', 'CreateProcess', 'pplllllppp', 'L').call(
        nil, 
        startup_command, 
        0, 0, 1, 0, 0, '.', startup_info, process_info)

    # TODO print the error code, or better yet a text message
    raise "Failed to start Instiki." if result == 0

    process_id = process_info.unpack('llll')[2]
    return self.new(process_id)
  end

  def self.clear_database
    ENV['RAILS_ENV'] = 'development'
    require INSTIKI_ROOT + '/config/environment.rb'
    [WikiReference, Revision, Page, WikiFile, Web, System].each { |entity| entity.delete_all }
  end

  def initialize(pid)
    @process_id = pid
  end

  def stop
    right_to_terminate_process = 1
    handle = Win32API.new('kernel32.dll', 'OpenProcess', 'lil', 'l').call(
        right_to_terminate_process, 0, @process_id)
    Win32API.new('kernel32.dll', 'TerminateProcess', 'll', 'L').call(handle, 0)
  end

end

begin
  require 'test/unit/ui/console/testrunner'
  Test::Unit::UI::Console::TestRunner.new(E2EInstikiTest.suite).start
rescue => e
    $stderr.puts 'Unhandled error during test execution'
    $stderr.puts e.message
    $stderr.puts e.backtrace
ensure 
  begin 
    E2EInstikiTest::shutdown
  rescue => e
    $stderr.puts 'Error during shutdown'
    $stderr.puts e.message
    $stderr.puts e.backtrace
  end
end
