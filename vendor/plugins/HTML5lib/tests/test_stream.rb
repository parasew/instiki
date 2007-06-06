require File.join(File.dirname(__FILE__), 'preamble')

require 'html5lib/inputstream'

class HTMLInputStreamTest < Test::Unit::TestCase
  include HTML5lib

  def test_char_ascii
    stream = HTMLInputStream.new("'")
    assert_equal('ascii', stream.char_encoding)
    assert_equal("'", stream.char)
  end

  def test_char_null
    stream = HTMLInputStream.new("\x00")
    assert_equal("\xef\xbf\xbd", stream.char)
  end

  def test_char_utf8
    stream = HTMLInputStream.new("\xe2\x80\x98")
    assert_equal('utf-8', stream.char_encoding)
    assert_equal("\xe2\x80\x98", stream.char)
  end

  def test_bom
    stream = HTMLInputStream.new("\xef\xbb\xbf" + "'")
    assert_equal('utf-8', stream.char_encoding)
    assert_equal("'", stream.char)
  end

  begin
    require 'iconv'

    def test_char_win1252
      stream = HTMLInputStream.new("\x91")
      assert_equal('windows-1252', stream.char_encoding)
      assert_equal("\xe2\x80\x98", stream.char)
    end

    def test_utf_16
      stream = HTMLInputStream.new("\xff\xfe" + " \x00"*1025)
      assert(stream.char_encoding, 'utf-16-le')
      assert_equal(1025, stream.chars_until(' ',true).length)
    end
  rescue LoadError
    puts "iconv not found, skipping iconv tests"
  end

  def test_newlines
    stream = HTMLInputStream.new("\xef\xbb\xbf" + "a\nbb\r\nccc\rdddd")
    assert_equal(0, stream.instance_eval {@tell})
    assert_equal("a\nbb\n", stream.chars_until('c'))
    assert_equal(6, stream.instance_eval {@tell})
    assert_equal([3,1], stream.position)
    assert_equal("ccc\ndddd", stream.chars_until('x'))
    assert_equal(14, stream.instance_eval {@tell})
    assert_equal([4,5], stream.position)
    assert_equal([0,1,4,8], stream.instance_eval {@new_lines})
  end
end
