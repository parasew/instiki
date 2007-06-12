require File.join(File.dirname(__FILE__), 'preamble')

require 'html5lib/treebuilders'
require 'html5lib/html5parser'


$tree_types_to_test = ['simpletree', 'rexml']

begin
  require 'hpricot'
  $tree_types_to_test.push('hpricot')
rescue LoadError
end

$CHECK_PARSER_ERRORS = false

puts 'Testing tree builders: ' + $tree_types_to_test * ', '


class Html5ParserTestCase < Test::Unit::TestCase
  include HTML5lib
  include TestSupport

  html5lib_test_files('tree-construction').each do |test_file|

    test_name = File.basename(test_file).sub('.dat', '')

    File.read(test_file).split("#data\n").each_with_index do |data, index|
      next if data.empty?
     
      innerHTML, input, expected_output, expected_errors =
        TestSupport.parseTestcase(data)

      $tree_types_to_test.each do |tree_name|
        define_method 'test_%s_%d_%s' % [ test_name, index + 1, tree_name ] do

          parser = HTMLParser.new(:tree => TreeBuilders[tree_name])
        
          if innerHTML
            parser.parseFragment(input, innerHTML)
          else
            parser.parse(input)
          end
        
          actual_output = convertTreeDump(parser.tree.testSerializer(parser.tree.document))

          assert_equal sortattrs(expected_output), sortattrs(actual_output), [
            'Input:', input,
            'Expected:', expected_output,
            'Recieved:', actual_output
          ].join("\n")

          if $CHECK_PARSER_ERRORS
            actual_errors = parser.errors.map do |(line, col), message|
              'Line: %i Col: %i %s' % [line, col, message]
            end
            assert_equal expected_errors.length, parser.errors.length, [
              'Expected errors:', expected_errors.join("\n"),
              'Actual errors:', actual_errors.join("\n") 
            ].join("\n")
          end
          
        end
      end
    end
  end

end
