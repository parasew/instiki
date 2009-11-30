# Unit tests for ApplicationController (the abstract controller class)

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require 'wiki_controller'

# Need some concrete class to test the abstract class features
class WikiController; def rescue_action(e) logger.error(e); raise e end; end

class ApplicationTest < ActionController::TestCase
  fixtures :webs, :pages, :revisions, :system
  
  Mime::LOOKUP["text/html"]             = HTML

  def setup
    @controller = WikiController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @wiki = Wiki.new
  end
  
  def test_utf8_header
    get :show, :web => 'wiki1', :id => 'HomePage'
    assert_equal 'text/html; charset=utf-8', @response.headers['Content-Type']
  end
  
  def test_mathplayer_mime_type
    @request.user_agent = 'MathPlayer'
    get :show, :web => 'wiki1', :id => 'HomePage'
    assert_equal 'application/xhtml+xml', @response.headers['Content-Type']
  end
  
  def test_validator_mime_type
    @request.user_agent = 'Validator'
    get :show, :web => 'wiki1', :id => 'HomePage'
    assert_equal 'application/xhtml+xml; charset=utf-8', @response.headers['Content-Type']
  end
  
  def test_accept_header_xhtml
    @request.user_agent = 'Mozilla/5.0'
    @request.env.update({'HTTP_ACCEPT' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' })
    get :show, :web => 'wiki1', :id => 'HomePage'
    assert_equal 'application/xhtml+xml; charset=utf-8', @response.headers['Content-Type']
  end
  
  def test_accept_header_html
    @request.user_agent = 'Foo'
    @request.env.update({'HTTP_ACCEPT' => 'text/html,application/xml;q=0.9,*/*;q=0.8' })
    get :show, :web => 'wiki1', :id => 'HomePage'
    assert_equal 'text/html; charset=utf-8', @response.headers['Content-Type']
  end

  def test_tex_mime_type
    get :tex, :web => 'wiki1', :id => 'HomePage'
    assert_equal 'text/plain; charset=utf-8', @response.headers['Content-Type']
  end
  
  def test_atom_mime_type
    get :atom_with_content, :web => 'wiki1'
    assert_equal 'application/atom+xml; charset=utf-8', @response.headers['Content-Type']
  end
  
  def test_connect_to_model_unknown_wiki
    get :show, :web => 'unknown_wiki', :id => 'HomePage'
    assert_response :missing
  end

end
