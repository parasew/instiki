require File.join(File.dirname(__FILE__), 'preamble')

require 'html5lib/html5parser'
require 'html5lib/treewalkers'
require 'html5lib/treebuilders'

$tree_types_to_test = {
  'simpletree' =>
    {:builder => HTML5lib::TreeBuilders['simpletree'],
     :walker  => HTML5lib::TreeWalkers['simpletree']},
  'rexml' =>
    {:builder => HTML5lib::TreeBuilders['rexml'],
     :walker  => HTML5lib::TreeWalkers['rexml']},
# 'hpricot' =>
#   {:builder => HTML5lib::TreeBuilders['hpricot'],
#    :walker  => HTML5lib::TreeWalkers['hpricot']},
}

puts 'Testing tree walkers: ' + $tree_types_to_test.keys * ', '

class TestTreeWalkers < Test::Unit::TestCase
  include HTML5lib::TestSupport

  def concatenateCharacterTokens(tokens)
    charactersToken = nil
    for token in tokens
        type = token[:type]
        if [:Characters, :SpaceCharacters].include?(type)
            if charactersToken == nil
                charactersToken = {:type => :Characters, :data => token[:data]}
            else
                charactersToken[:data] += token[:data]
            end
        else
            if charactersToken != nil
                yield charactersToken
                charactersToken = nil
            end
            yield token
        end
    end
    yield charactersToken if charactersToken != nil
  end

  def convertTokens(tokens)
    output = []
    indent = 0
    concatenateCharacterTokens(tokens) do |token|
        case token[:type]
        when :StartTag, :EmptyTag
            output << "#{' '*indent}<#{token[:name]}>"
            indent += 2
            for name, value in token[:data].to_a.sort
                next if name=='xmlns'
                output << "#{' '*indent}#{name}=\"#{value}\""
            end
            indent -= 2 if token[:type] == :EmptyTag
        when :EndTag
            indent -= 2
        when :Comment
            output << "#{' '*indent}<!-- #{token[:data]} -->"
        when :Doctype
            output << "#{' '*indent}<!DOCTYPE #{token[:name]}>"
        when :Characters, :SpaceCharacters
            output << "#{' '*indent}\"#{token[:data]}\""
        else
            # TODO: what to do with errors?
        end
    end
    return output.join("\n")
  end

  html5lib_test_files('tree-construction').each do |test_file|

    test_name = File.basename(test_file).sub('.dat', '')

    File.read(test_file).split("#data\n").each_with_index do |data, index|
      next if data.empty?

      innerHTML, input, expected_output, expected_errors =
        HTML5lib::TestSupport::parseTestcase(data)

      rexml = $tree_types_to_test['rexml']
      $tree_types_to_test.each do |tree_name, treeClass|

        define_method "test_#{test_name}_#{index}_#{tree_name}" do

          parser = HTML5lib::HTMLParser.new(:tree => treeClass[:builder])

          if innerHTML
            parser.parseFragment(input, innerHTML)
          else
            parser.parse(input)
          end

          document = parser.tree.getDocument

          begin
            output = sortattrs(convertTokens(treeClass[:walker].new(document)))
            expected = sortattrs(expected_output)
            errorMsg = "\n\nExpected:\n#{expected}\nRecieved:\n#{output}\n"
            assert_equal(expected, output, errorMsg)
          rescue NotImplementedError
            # Amnesty for those that confess...
          end
        end
      end
   end
  end
end
