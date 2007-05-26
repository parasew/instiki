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

puts 'Testing: ' + $tree_types_to_test * ', '


class Html5ParserTestCase < Test::Unit::TestCase

    def self.startswith?(a, b)
        b[0... a.length] == a
    end

    def self.parseTestcase(data)
        innerHTML = nil
        input = []
        output = []
        errors = []
        currentList = input
        data.split(/\n/).each do |line|
            if !line.empty? and !startswith?("#errors", line) and
              !startswith?("#document", line) and
              !startswith?("#data", line) and
              !startswith?("#document-fragment", line)

                if currentList == output and startswith?("|", line)
                    currentList.push(line[2..-1])
                else
                    currentList.push(line)
                end
            elsif line == "#errors"
                currentList = errors
            elsif line == "#document" or startswith?("#document-fragment", line)
                if startswith?("#document-fragment", line)
                    innerHTML = line[19..-1]
                    raise AssertionError unless innerHTML
                end
                currentList = output
            end
        end
        return innerHTML, input.join("\n"), output.join("\n"), errors
    end
    
    # convert the output of str(document) to the format used in the testcases
    def convertTreeDump(treedump)
        treedump.split(/\n/)[1..-1].map { |line| (line.length > 2 and line[0] == ?|) ? line[3..-1] : line }.join("\n")
    end

    def sortattrs(output)
        output.gsub(/^(\s+)\w+=.*(\n\1\w+=.*)+/) { |match| match.split("\n").sort.join("\n") }
    end

    html5lib_test_files('tree-construction').each do |test_file|

        test_name = File.basename(test_file).sub('.dat', '')

        File.read(test_file).split("#data\n").each_with_index do |data, index|
            next if data.empty?
       
            innerHTML, input, expected_output, expected_errors = parseTestcase(data)

            $tree_types_to_test.each do |tree_name|
                define_method 'test_%s_%d_%s' % [ test_name, index + 1, tree_name ] do

                    parser = HTML5lib::HTMLParser.new(:tree => HTML5lib::TreeBuilders.getTreeBuilder(tree_name))
                
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
                        assert_equal parser.errors.length, expected_errors.length, [
                            'Expected errors:', expected_errors.join("\n"),
                            'Actual errors:', actual_errors.join("\n") 
                        ].join("\n")
                    end
                    
                end
            end
        end
    end

end
