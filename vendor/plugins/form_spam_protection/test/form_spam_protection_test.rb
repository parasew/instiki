require File.dirname(__FILE__) + '/test_helper'

class FormSpamProtectionTest < Test::Unit::TestCase
  def setup
    @controller = ProtectedController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_index_form_is_protected
    get :index
    assert_response :success
    assert_select 'code input[type="hidden"]'
  end
  
  def test_index_form_handler_is_protected
    post :index
    assert_response 403
    assert_equal "You must have Javascript on to submit this form.", @response.body

    get :index
    form_key_tag = assert_select('code input[type="hidden"]').first
    submit_with_valid_key = lambda { post :index, :_form_key => form_key_tag.attributes['value'] }
    
    submit_with_valid_key.call
    assert_response :success
    assert_equal "Submission successful", @response.body
    
    3.times(&submit_with_valid_key) # Total of 4 times
    assert_response 403
    assert_equal "You cannot resubmit this form again.", @response.body
  end
  
  def test_unprotected_form_is_unprotected
    get :unprotected
    assert_response :success
    assert_select 'input[type="hidden"]', false
  end
end
