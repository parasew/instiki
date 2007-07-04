require File.join(File.dirname(__FILE__), 'preamble')

require 'html5/inputstream'

class Html5EncodingTestCase < Test::Unit::TestCase
  include HTML5
  include TestSupport

  begin
    require 'rubygems'
    require 'UniversalDetector'

    def test_chardet
      file = File.open(File.join(TESTDATA_DIR, 'encoding', 'chardet', 'test_big5.txt'), 'r')
      stream = HTML5::HTMLInputStream.new(file, :chardet => true)
      assert_equal 'big5', stream.char_encoding.downcase
    rescue LoadError
      puts "chardet not found, skipping chardet tests"
    end
  end

  html5_test_files('encoding').each do |test_file|        
    test_name = File.basename(test_file).sub('.dat', '').tr('-', '')

    TestData.new(test_file, %w(data encoding)).
      each_with_index do |(input, encoding), index|

      define_method 'test_%s_%d' % [ test_name, index + 1 ] do
        stream = HTML5::HTMLInputStream.new(input, :chardet => false)
        assert_equal encoding.downcase, stream.char_encoding.downcase, input
      end
    end
  end

end
