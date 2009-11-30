require File.join(File.dirname(__FILE__), 'preamble')

require 'html5/html5parser'
require 'html5/serializer'
require 'html5/treewalkers'

#Run the serialize error checks
checkSerializeErrors = false

class JsonWalker < HTML5::TreeWalkers::Base
  def each
    @tree.each do |token|
      case token[0]
      when 'StartTag'
        yield start_tag(token[1], token[2])
      when 'EndTag'
        yield end_tag(token[1])
      when 'EmptyTag'
        yield empty_tag(token[1], token[2])
      when 'Comment'
        yield comment(token[1])
      when 'Characters', 'SpaceCharacters'
        text(token[1]) {|textToken| yield textToken}
      when 'Doctype'
        yield doctype(token[1], token[2], token[3])
      else
        raise "Unknown token type: " + token[0]
      end
    end
  end
end

class Html5SerializeTestcase < Test::Unit::TestCase
  html5_test_files('serializer').each do |filename|
    test_name = File.basename(filename).sub('.test', '')
    tests = JSON::parse(open(filename).read)
    tests['tests'].each_with_index do |test, index|

      define_method "test_#{test_name}_#{index+1}" do
        if test["options"] and test["options"]["encoding"]
          test["options"][:encoding] = test["options"]["encoding"]
        end

        result = HTML5::HTMLSerializer.
          serialize(JsonWalker.new(test["input"]), (test["options"] || {}))
        expected = test["expected"]
        if expected.length == 1
          assert_equal(expected[0], result, test["description"])
        elsif !expected.include?(result)
          flunk("Expected: #{expected.inspect}, Received: #{result.inspect}")
        end

        next if test_name == 'optionaltags'

        result = HTML5::XHTMLSerializer.
          serialize(JsonWalker.new(test["input"]), (test["options"] || {}))
        expected = test["xhtml"] || test["expected"]
        if expected.length == 1
          assert_equal(expected[0], result, test["description"])
        elsif !expected.include?(result)
          flunk("Expected: #{expected.inspect}, Received: #{result.inspect}")
        end
      end

    end
  end
end
