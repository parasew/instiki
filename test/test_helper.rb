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


# This module is to be included in unit tests that involve matching chunks.
# It provides a easy way to test whether a chunk matches a particular string
# and any the values of any fields that should be set after a match.
class ContentStub < String
  attr_reader :chunks, :content
  def initialize(str)
    super
    @chunks = []
  end
end

module ChunkMatch

  # Asserts a number of tests for the given type and text.
  def match(chunk_type, test_text, expected_chunk_state)
    if chunk_type.respond_to? :pattern
      assert_match(chunk_type.pattern, test_text)
    end

    content = ContentStub.new(test_text)
	chunk_type.apply_to(content)

    # Test if requested parts are correct.
    expected_chunk_state.each_pair do |a_method, expected_value|
      assert content.chunks.last.kind_of?(chunk_type)
      assert_respond_to(content.chunks.last, a_method)
      assert_equal(expected_value, content.chunks.last.send(a_method.to_sym), 
          "Wrong #{a_method} value")
    end
  end
end

