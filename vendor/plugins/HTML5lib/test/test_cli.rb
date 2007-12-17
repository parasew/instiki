require File.join(File.dirname(__FILE__), 'preamble')
require "html5/cli"

class TestCli < Test::Unit::TestCase
  def test_open_input
    assert_equal $stdin, HTML5::CLI.open_input('-')
    assert_kind_of StringIO, HTML5::CLI.open_input('http://whatwg.org/')
    assert_kind_of File, HTML5::CLI.open_input('testdata/sites/google-results.htm')
  end
  
  def test_parse_opts
    HTML5::CLI.parse_opts [] # TODO test defaults
    assert_equal 'hpricot', HTML5::CLI.parse_opts(['-b', 'hpricot']).treebuilder
    assert_equal 'hpricot', HTML5::CLI.parse_opts(['--treebuilder', 'hpricot']).treebuilder
  end
end