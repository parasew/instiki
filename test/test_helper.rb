ENV['RAILS_ENV'] ||= 'test'
require File.dirname(__FILE__) + '/../config/environment'
require 'application'

require 'test/unit'
require 'action_controller/test_process'

# Convenient setup method for Test::Unit::TestCase
class Test::Unit::TestCase

  private

  def setup_controller_test(controller_class = nil, host = nil)
    if controller_class
      @controller = controller_class
    elsif self.class.to_s =~ /^(\w+Controller)Test$/
      @controller = Object::const_get($1)
    else
      raise "Cannot derive the name of controller under test from class name #{self.class}"
    end
    @request, @response = ActionController::TestRequest.new, ActionController::TestResponse.new
    @request.host = host || 'localhost'
    return @request, @response
  end

end

class WikiServiceWithNoPersistence
  include AbstractWikiService
  def initialize
    init_wiki_service
  end
end

# With the new cookies infrastructure, @response.cookies['foo'] is no good anymore.
# Pending implementation in Rails, here is a convenience method for accessing cookies from a test

module ActionController
  class TestResponse
    # Returns the response cookies, converted to a Hash of (name => CGI::Cookie) pairs
    # Example:
    # 
    # assert_equal ['AuthorOfNewPage'], r.cookies['author'].value
    def cookies
      headers['cookie'].inject({}) { |hash, cookie| hash[cookie.name] = cookie; hash }
    end
  end
end
