require 'fileutils'
require 'test/unit'

INSTIKI_ROOT = File.expand_path(File.dirname(__FILE__) + "/../..")
require(File.expand_path(File.dirname(__FILE__) + "/../../config/environment"))

# Use instiki/../watir, if such a directory exists; This can be a CVS HEAD. 
# Otherwise Watir has to be installed in ruby/lib.
$:.unshift INSTIKI_ROOT + '/../watir' if File.exists?(INSTIKI_ROOT + '/../watir/watir.rb')
require 'watir'

INSTIKI_PORT = 2501
HOME = "http://localhost:#{INSTIKI_PORT}"

class E2EInstikiTest < Test::Unit::TestCase

  def startup
    @@instiki = InstikiController.start

    sleep 5
    @@ie = Watir::IE.start(HOME)

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
    ie.link(:text, 'Edit Page').click
    assert_equal url(:edit, 'HomePage'), ie.url
    
    # Add reference to a non-existant wiki page
    ie.text_field(:name, 'content').set('[[Another Wiki Page]]')
    ie.button(:value, 'Submit').click
    assert_equal url(:show, 'HomePage'), ie.url
    assert_equal '?', ie.link(:url, url(:show, 'Another+Wiki+Page')).text
    
    # Edit the first revision of a page
    ie.link(:url, url(:show, 'Another+Wiki+Page')).click
    # this c lick must be redirected to 'new' page
    assert_equal url(:new, 'Another+Wiki+Page'), ie.url
    ie.text_field(:name, 'content').set('First revision of Another Wiki Page, linked from HomePage')
    ie.button(:value, 'Submit').click

    # Check contents of the new page
    assert_equal url(:show, 'Another+Wiki+Page'), ie.url
    assert_match /First revision of Another Wiki Page, linked from Home Page/, ie.text
    assert_match /Linked from: HomePage/, ie.text

    # There must be three links to HomePage - main menu, contents of the page and navigation bar
    links_to_homepage = ie.links.to_a.select { |link| link.text == 'Home Page' }
    assert_equal 3, links_to_homepage.size
    links_to_homepage.each { |link| assert_equal url(:show, 'HomePage'), link.href }

    # Check also the "created on ... by ..." footnote
    date_pattern = '(January|February|March|April|May|June|July|August|September|October|November|December) \d\d?, \d\d\d\d \d\d:\d\d'
    assert_match Regexp.new('Created on ' + date_pattern + ' by Anonymous Coward\?'), ie.text
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
    assert_equal HOME + '/wiki/print/HomePage', ie.link(:text, 'Print').href
  end
  
  def check_footnote
    assert_match /This site is running on Instiki/, ie.text
    assert_equal 'http://instiki.org/', ie.link(:text, 'Instiki').href
    assert_match /Powered by Ruby on Rails/, ie.text
    assert_equal 'http://rubyonrails.com/', ie.link(:text, 'Ruby on Rails').href
  end
  
  def setup_web
    assert_equal 'Wiki', ie.textField(:name, 'web_name').value
    assert_equal 'wiki', ie.textField(:name, 'web_address').value
    assert_equal '', ie.textField(:name, 'password').value
    assert_equal '', ie.textField(:name, 'password_check').value
    
    ie.textField(:name, 'password').set('123')
    ie.textField(:name, 'password_check').set('123')
    ie.button(:value, 'Setup').click
    assert_equal url(:new, 'HomePage'), ie.url
  end

  def setup_home_page
    ie.textField(:name, 'content').set('Homepage of a test wiki')
    ie.button(:value, 'Submit').click
    assert_equal url(:show, 'HomePage'), ie.url
  end

  def url(operation, page_name)
    case operation
    when :edit, :new, :show
      "#{HOME}/wiki/#{operation}/#{page_name}"
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
    
    startup_command =
        "ruby #{RAILS_ROOT}/instiki.rb --storage #{prepare_storage} " +
        "     --port #{INSTIKI_PORT} --environment development"
    
    result = Win32API.new('kernel32.dll', 'CreateProcess', 'pplllllppp', 'L').call(
        nil, 
        startup_command, 
        0, 0, 1, 0, 0, '.', startup_info, process_info)
        
    # TODO print the error code, or better yet a text message
    raise "Failed to start Instiki." if result == 0

    process_id = process_info.unpack('llll')[2]
    return self.new(process_id)
  end
  
  def self.prepare_storage
    storage_path = INSTIKI_ROOT + '/storage/e2e'
    FileUtils.rm_rf(storage_path) if File.exists? storage_path
    FileUtils.mkdir_p(storage_path)
    storage_path
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
