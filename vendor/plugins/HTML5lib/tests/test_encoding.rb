require File.join(File.dirname(__FILE__), 'preamble')

require 'html5lib/inputstream'

class Html5EncodingTestCase < Test::Unit::TestCase

  begin
    require 'rubygems'
    require 'UniversalDetector'

    def test_chardet
      file = File.open(File.join(TESTDATA_DIR, 'encoding', 'chardet', 'test_big5.txt'), 'r')
      stream = HTML5lib::HTMLInputStream.new(file, :chardet => true)
      assert_equal 'big5', stream.char_encoding.downcase
    rescue LoadError
      puts "chardet not found, skipping chardet tests"
    end
  end

  html5lib_test_files('encoding').each do |test_file|        
    test_name = File.basename(test_file).sub('.dat', '').tr('-', '')

    File.read(test_file).split("#data\n").each_with_index do |data, index|
      next if data.empty?
      input, encoding = data.split(/\n#encoding\s+/, 2)
      encoding = encoding.split[0]

      define_method 'test_%s_%d' % [ test_name, index + 1 ] do
        stream = HTML5lib::HTMLInputStream.new(input, :chardet => false)
        assert_equal encoding.downcase, stream.char_encoding.downcase, input
      end
    end
  end

end
