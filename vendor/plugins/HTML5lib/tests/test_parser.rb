require File.join(File.dirname(__FILE__), 'preamble')

require 'html5/treebuilders'
require 'html5/html5parser'


$tree_types_to_test = ['simpletree', 'rexml']

begin
  require 'hpricot'
  $tree_types_to_test.push('hpricot')
rescue LoadError
end

$CHECK_PARSER_ERRORS = ARGV.delete('-p') # TODO

puts 'Testing tree builders: ' + $tree_types_to_test * ', '


class Html5ParserTestCase < Test::Unit::TestCase
  include HTML5
  include TestSupport

  html5_test_files('tree-construction').each do |test_file|

    test_name = File.basename(test_file).sub('.dat', '')

    TestData.new(test_file, %w(data errors document-fragment document)).
      each_with_index do |(input, errors, innerHTML, expected), index|

      expected = expected.gsub("\n| ","\n")[2..-1]

      $tree_types_to_test.each do |tree_name|
        define_method 'test_%s_%d_%s' % [ test_name, index + 1, tree_name ] do

          parser = HTMLParser.new(:tree => TreeBuilders[tree_name])
        
          if innerHTML
            parser.parseFragment(input, innerHTML)
          else
            parser.parse(input)
          end
        
          actual_output = convertTreeDump(parser.tree.testSerializer(parser.tree.document))

          assert_equal sortattrs(expected), sortattrs(actual_output), [
            '', 'Input:', input,
            '', 'Expected:', expected,
            '', 'Recieved:', actual_output
          ].join("\n")

          if $CHECK_PARSER_ERRORS
            actual_errors = parser.errors.map do |(line, col), message|
              'Line: %i Col: %i %s' % [line, col, message]
            end
            assert_equal errors.length, parser.errors.length, [
              'Input', input + "\n",
              'Expected errors:', errors.join("\n"),
              'Actual errors:', actual_errors.join("\n") 
            ].join("\n")
          end
          
        end
      end
    end
  end

end
