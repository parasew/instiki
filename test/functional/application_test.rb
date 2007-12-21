# Unit tests for ApplicationController (the abstract controller class)

require File.dirname(__FILE__) + '/../test_helper'
require 'wiki_controller'
require 'rexml/document'

# Need some concrete class to test the abstract class features
class WikiController; def rescue_action(e) logger.error(e); raise e end; end

class ApplicationTest < Test::Unit::TestCase
  fixtures :webs, :pages, :revisions, :system
  
  def setup
    @controller = WikiController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @wiki = Wiki.new
  end
  
  def test_utf8_header
    get :show, :web => 'wiki1', :id => 'HomePage'
    assert_equal 'text/html; charset=UTF-8', @response.headers['type']
  end
  
  def test_connect_to_model_unknown_wiki
    get :show, :web => 'unknown_wiki', :id => 'HomePage'
    assert_response :missing
  end

end
