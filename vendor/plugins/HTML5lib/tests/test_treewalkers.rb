require File.join(File.dirname(__FILE__), 'preamble')

require 'html5/html5parser'
require 'html5/treewalkers'
require 'html5/treebuilders'

$tree_types_to_test = {
  'simpletree' =>
    {:builder => HTML5::TreeBuilders['simpletree'],
     :walker  => HTML5::TreeWalkers['simpletree']},
  'rexml' =>
    {:builder => HTML5::TreeBuilders['rexml'],
     :walker  => HTML5::TreeWalkers['rexml']},
  'hpricot' =>
    {:builder => HTML5::TreeBuilders['hpricot'],
     :walker  => HTML5::TreeWalkers['hpricot']},
}

puts 'Testing tree walkers: ' + $tree_types_to_test.keys * ', '

class TestTreeWalkers < Test::Unit::TestCase
  include HTML5::TestSupport

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
            if token[:name] and token[:name].any?
              output << "#{' '*indent}<!DOCTYPE #{token[:name]}>"
            else
              output << "#{' '*indent}<!DOCTYPE >"
            end
        when :Characters, :SpaceCharacters
            output << "#{' '*indent}\"#{token[:data]}\""
        else
            # TODO: what to do with errors?
      end
    end
    return output.join("\n")
  end

  html5_test_files('tree-construction').each do |test_file|

    test_name = File.basename(test_file).sub('.dat', '')
    next if test_name == 'tests5' # TODO

    TestData.new(test_file, %w(data errors document-fragment document)).
      each_with_index do |(input, errors, inner_html, expected), index|

      expected = expected.gsub("\n| ","\n")[2..-1]

      $tree_types_to_test.each do |tree_name, tree_class|

        define_method "test_#{test_name}_#{index}_#{tree_name}" do

          parser = HTML5::HTMLParser.new(:tree => tree_class[:builder])

          if inner_html
            parser.parse_fragment(input, inner_html)
          else
            parser.parse(input)
          end

          document = parser.tree.get_document

          begin
            output = sortattrs(convertTokens(tree_class[:walker].new(document)))
            expected = sortattrs(expected)
            assert_equal expected, output, [
              '', 'Input:', input,
              '', 'Expected:', expected,
              '', 'Recieved:', output
            ].join("\n")
          rescue NotImplementedError
            # Amnesty for those that confess...
          end
        end
      end
   end
  end
end
