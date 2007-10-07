require File.join(File.dirname(__FILE__), 'preamble')
require "test/unit"
require "html5/inputstream"

class TestHtml5Inputstream < Test::Unit::TestCase
  def test_newline_in_queue
    stream = HTML5::HTMLInputStream.new("\nfoo")
    stream.unget(stream.char)
    assert_equal [1, 0], stream.position
  end
  
  def test_buffer_boundary
    stream = HTML5::HTMLInputStream.new("abcdefghijklmnopqrstuvwxyz" * 50, :encoding => 'windows-1252')
    1022.times{stream.char}
    assert_equal "i", stream.char
  end
end