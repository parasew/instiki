# Unit tests for ApplicationController (the abstract controller class)

require File.dirname(__FILE__) + '/../test_helper'
require 'wiki_controller'
require 'rexml/document'

# Need some concrete class to test the abstract class features
class WikiController; def rescue_action(e) logger.error(e); raise e end; end

class ApplicationTest < Test::Unit::TestCase

  def setup
    setup_test_wiki
    setup_controller_test(WikiController)
  end

  def tear_down
    tear_down_wiki
  end

  def test_utf8_header
    r = process('show', 'web' => 'wiki1', 'id' => 'HomePage')
    assert_equal 'text/html; charset=UTF-8', r.headers['Content-Type']
  end
  
  def test_connect_to_model_unknown_wiki
    r = process('show', 'web' => 'unknown_wiki', 'id' => 'HomePage')
    assert_equal 404, r.response_code
  end

end
