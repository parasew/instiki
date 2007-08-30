require File.join(File.dirname(__FILE__), 'preamble')
require "html5/sniffer"

class TestFeedTypeSniffer < Test::Unit::TestCase
  include HTML5
  include TestSupport
  include Sniffer
  
  html5_test_files('sniffer').each do |test_file|
    test_name = File.basename(test_file).sub('.test', '')

    tests = JSON.parse(File.read(test_file))

    tests.each_with_index do |data, index|
      define_method('test_%s_%d' % [test_name, index + 1]) do
        assert_equal data['type'], html_or_feed(data['input'])
      end
    end
  end
  # each_with_index do |t, i|
  #     define_method "test_#{i}" do
  #       assert_equal t[0], sniff_feed_type(t[1])
  #     end
  #   end
  

end