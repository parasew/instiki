require 'watir'
require 'fileutils'
require 'test/unit'

INSTIKI_ROOT = File.expand_path(File.dirname(__FILE__) + "/../..")
require(File.expand_path(File.dirname(__FILE__) + "/../../config/environment"))

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
    ie.goto(HOME)
    ie
  end

  def test_home_page_contents
    assert_equal HOME + '/wiki/list', ie.link(:text, 'All Pages').href
    assert_equal HOME + '/wiki/recently_revised', ie.link(:text, 'Recently Revised').href
  end

  private
  
  def setup_web
    assert_equal 'Wiki', ie.textField(:name, 'web_name').value
    assert_equal 'wiki', ie.textField(:name, 'web_address').value
    assert_equal '', ie.textField(:name, 'password').value
    assert_equal '', ie.textField(:name, 'password_check').value
    
    ie.textField(:name, 'password').set('123')
    ie.textField(:name, 'password_check').set('123')
    ie.button(:value, 'Setup').click
    assert_equal HOME + '/wiki/new/HomePage', ie.url
  end

  def setup_home_page
    ie.textField(:name, 'content').set('Homepage of a test wiki')
    ie.button(:value, 'Submit').click
    assert_equal HOME + '/wiki/show/HomePage', ie.url
  end

  def bp
    require 'breakpoint'
    breakpoint
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
