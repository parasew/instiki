require File.join(File.dirname(__FILE__), 'preamble')

require 'html5/inputstream'

class HTMLInputStreamTest < Test::Unit::TestCase
  include HTML5

  def getc stream
    if String.method_defined? :force_encoding
      stream.char.force_encoding('binary')
    else
      stream.char
    end
  end

  def test_char_ascii
    stream = HTMLInputStream.new("'", :encoding=>'ascii')
    assert_equal('ascii', stream.char_encoding)
    assert_equal("'", stream.char)
  end

  def test_char_null
    stream = HTMLInputStream.new("\x00")
    assert_equal("\xef\xbf\xbd", getc(stream))
  end

  def test_char_utf8
    stream = HTMLInputStream.new("\xe2\x80\x98", :encoding=>'utf-8')
    assert_equal('utf-8', stream.char_encoding)
    assert_equal("\xe2\x80\x98", getc(stream))
  end

  def test_char_win1252
    stream = HTMLInputStream.new("\xa2\xc5\xf1\x92\x86")
    assert_equal('windows-1252', stream.char_encoding)
    assert_equal("\xc2\xa2", getc(stream))
    assert_equal("\xc3\x85", getc(stream))
    assert_equal("\xc3\xb1", getc(stream))
    assert_equal("\xe2\x80\x99", getc(stream))
    assert_equal("\xe2\x80\xa0", getc(stream))
  end

  def test_bom
    stream = HTMLInputStream.new("\xef\xbb\xbf" + "'")
    assert_equal('utf-8', stream.char_encoding)
    assert_equal("'", stream.char)
  end

  begin
    require 'iconv'

    def test_utf_16
      input = Iconv.new('utf-16', 'utf-8').iconv(' '*1025)
      stream = HTMLInputStream.new(input)
      assert('utf-16-le', stream.char_encoding)
      assert_equal(1025, stream.chars_until(' ', true).length)
    end
  rescue LoadError
    puts "iconv not found, skipping iconv tests"
  end

  def test_newlines
    stream = HTMLInputStream.new("\xef\xbb\xbf" + "a\nbb\r\nccc\rdddd")
    assert_equal([1,0], stream.position)
    assert_equal("a\nbb\n", stream.chars_until('c'))
    assert_equal([3,0], stream.position)
    assert_equal("ccc\ndddd", stream.chars_until('x'))
    assert_equal([4,4], stream.position)
    assert_equal([1,2,3], stream.instance_eval {@line_lengths})
  end
end
