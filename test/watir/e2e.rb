require 'watir'
require 'fileutils'
require 'test/unit'

INSTIKI_ROOT = File.expand_path(File.dirname(__FILE__) + "/../..")
require(File.expand_path(File.dirname(__FILE__) + "/../../config/environment"))

INSTIKI_PORT = 2501
HOME = "http://localhost:#{INSTIKI_PORT}"

class Win32API
# FIXME this should raise an error whenever an API call returns an error
#  alias __original_call call
#  def call(*args)
#    __original_call(*args)
#    last_error = Win32API.new('kernel32.dll', 'GetLastError', '', 'L').__original_call()
#    raise "Win32API call to #{args.inspect} has failed with error code #{last_error}" if last_error
#  end
end

class E2EInstikiTest < Test::Unit::TestCase

  def startup
    
    createProcess = 
    startup_info = [68].pack('lx64')
    @@instiki = [0, 0, 0, 0].pack('llll')
    Win32API.new('kernel32.dll', 'CreateProcess', 'pplllllppp', 'L').call(
        nil, 
        "ruby #{RAILS_ROOT}/instiki.rb --storage #{prepare_storage} " +
        "    --port #{INSTIKI_PORT} --environment development", 
        0, 0, 1, 0, 0, '.', startup_info, @@instiki)

    sleep 5
    @@ie = Watir::IE.start(HOME)

    setup_web
    setup_home_page
    
    @@ie
  end
  
  def self.shutdown  
    process_id = @@instiki.unpack('llll')[2]
    right_to_terminate_process = 1
    handle = Win32API.new('kernel32.dll', 'OpenProcess', 'lil', 'l').call(
        right_to_terminate_process, 0, process_id)
    Win32API.new('kernel32.dll', 'TerminateProcess', 'll', 'L').call(handle, 0)

    @@ie.close if defined? @@ie
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
  
  def prepare_storage
    storage_path = INSTIKI_ROOT + '/storage/e2e'
    FileUtils.rm_rf(storage_path) if File.exists? storage_path
    FileUtils.mkdir_p(storage_path)
    storage_path
  end
  
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
