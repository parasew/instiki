require File.join(File.dirname(__FILE__), 'preamble')

require 'html5/treebuilders'
require 'html5/html5parser'
require 'html5/cli'

$tree_types_to_test = ['simpletree', 'rexml']

begin
  require 'hpricot'
  $tree_types_to_test.push('hpricot')
rescue LoadError
end

class Html5ParserTestCase < Test::Unit::TestCase
  include HTML5
  include TestSupport

  html5_test_files('tree-construction').each do |test_file|

    test_name = File.basename(test_file).sub('.dat', '')

    TestData.new(test_file, %w(data errors document-fragment document)).each_with_index do |(input, errors, inner_html, expected), index|

      errors = errors.split("\n")
      expected = expected.gsub("\n| ","\n")[2..-1]

      $tree_types_to_test.each do |tree_name|
        define_method 'test_%s_%d_%s' % [ test_name, index + 1, tree_name ] do

          parser = HTMLParser.new(:tree => TreeBuilders[tree_name])

          if inner_html
            parser.parse_fragment(input, inner_html)
          else
            parser.parse(input)
          end

          actual_output = convertTreeDump(parser.tree.testSerializer(parser.tree.document))

          assert_equal sortattrs(expected), sortattrs(actual_output), [
            '', 'Input:', input,
            '', 'Expected:', expected,
            '', 'Recieved:', actual_output
          ].join("\n")

          actual_errors = parser.errors.map do |(line, col), message, datavars|
            message = CLI::PythonicTemplate.new(E[message]).to_s(datavars)
            "Line: #{line} Col: #{col} #{message}"
          end

          assert_equal errors, actual_errors, [
            '', 'Input', input,
            '', "Expected errors (#{errors.length}):", errors.join("\n"),
            '', "Actual errors (#{actual_errors.length}):",
                 actual_errors.join("\n") + "\n"
          ].join("\n")
        end
      end
    end
  end

end
