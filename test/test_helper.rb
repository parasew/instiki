ENV['RAILS_ENV'] = 'test'
require File.expand_path(File.dirname(__FILE__) + '/../config/environment')
require 'application'
require 'test/unit'
require 'breakpoint'
require 'action_controller/test_process'

# Uncomment this variable to have assert_success check that response bodies are valid XML
$validate_xml_in_assert_success = true

# Convenient setup method for Test::Unit::TestCase
class Test::Unit::TestCase

  private

  def setup_controller_test(controller_class = nil, host = nil)
    if controller_class
      @controller = controller_class.new
    elsif self.class.to_s =~ /^(\w+Controller)Test$/
      @controller = Object::const_get($1).new
    else
      raise "Cannot derive the name of controller under test from class name #{self.class}"
    end
    @request, @response = ActionController::TestRequest.new, ActionController::TestResponse.new
    @request.host = host || 'localhost'
    return @request, @response
  end

  # Wiki fixture for tests

  def setup_test_wiki
    @wiki = ApplicationController.wiki = WikiServiceWithNoPersistence.new
    @web = @wiki.create_web('Test Wiki 1', 'wiki1')
    @home = @wiki.write_page('wiki1', 'HomePage', 'First revision of the HomePage end', Time.now, 
        Author.new('AnAuthor', '127.0.0.1'))
  end
  
  def setup_wiki_with_three_pages
    @oak = @wiki.write_page('wiki1', 'Oak',
        "All about oak.\n" +
        "category: trees", 
        5.minutes.ago, Author.new('TreeHugger', '127.0.0.2'))
    @elephant = @wiki.write_page('wiki1', 'Elephant',
        "All about elephants.\n" +
        "category: animals", 
        10.minutes.ago, Author.new('Guest', '127.0.0.2'))
  end
  
  def setup_wiki_with_30_pages
    (1..30).each { |i|
      @wiki.write_page('wiki1', "page#{i}", "Test page #{i}\ncategory: test", 
                                Time.local(1976, 10, i, 12, 00, 00), Author.new('Dema', '127.0.0.2'))
    }
  end
  
  def tear_down_wiki
    ApplicationController.wiki = nil
  end

end

class WikiServiceWithNoPersistence
  include AbstractWikiService
  def initialize
    init_wiki_service
  end
  
  def storage_path
    RAILS_ROOT + '/storage/test/'
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

if defined? $validate_xml_in_assert_success and $validate_xml_in_assert_success == true
  module Test
    module Unit
      module Assertions
        unless method_defined? :__assert_success_before_ovverride_by_instiki
          alias :__assert_success_before_ovverride_by_instiki :assert_success 
        end
        def assert_success
          __assert_success_before_ovverride_by_instiki
          if @response.body.kind_of?(Proc) then # it's a file download, not an HTML content
          else assert_nothing_raised(@response.body) { REXML::Document.new(@response.body) } end
        end
      end
    end
  end
end
