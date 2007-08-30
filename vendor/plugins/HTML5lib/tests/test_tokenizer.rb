require File.join(File.dirname(__FILE__), 'preamble')

require 'html5/tokenizer'

require 'tokenizer_test_parser'

class Html5TokenizerTestCase < Test::Unit::TestCase

  def assert_tokens_match(expectedTokens, receivedTokens, ignoreErrorOrder, message)
    if !ignoreErrorOrder
      return expectedTokens == receivedTokens
    else
      #Sort the tokens into two groups; non-parse errors and parse errors
      expected = [[],[]]
      received = [[],[]]
      
      for token in expectedTokens
        if token != "ParseError"
          expected[0] << token
        else
          expected[1] << token
        end
      end

      for token in receivedTokens
        if token != "ParseError"
          received[0] << token
        else
          received[1] << token
        end
      end
      assert_equal expected, received, message
    end
  end

  def type_of?(token_name, token)
    token != 'ParseError' and token_name == token.first
  end

  def convert_attribute_arrays_to_hashes(tokens)
    tokens.inject([]) do |tokens, token|
      token[2] = Hash[*token[2].reverse.flatten] if type_of?('StartTag', token)
      tokens << token
    end
  end
  
  def concatenate_consecutive_characters(tokens)
    tokens.inject([]) do |tokens, token|
      if type_of?('Character', token) and tokens.any? and type_of?('Character', tokens.last)
        tokens.last[1] = tokens.last[1] + token[1]
        next tokens
      end
      tokens << token
    end
  end

  def tokenizer_test(data)
    (data['contentModelFlags'] || [:PCDATA]).each do |content_model_flag|
      message = [
        '', 'Description:', data['description'],
        '', 'Input:', data['input'],
        '', 'Content Model Flag:', content_model_flag,
        '' ] * "\n"

      assert_nothing_raised message do
        tokenizer = HTML5::HTMLTokenizer.new(data['input'])

        tokenizer.content_model_flag = content_model_flag.to_sym

        tokenizer.current_token = {:type => :startTag, :name => data['lastStartTag']} if data.has_key?('lastStartTag')

        tokens = TokenizerTestParser.new(tokenizer).parse

        actual = concatenate_consecutive_characters(convert_attribute_arrays_to_hashes(tokens))

        expected = concatenate_consecutive_characters(data['output'])

        assert_tokens_match expected, actual, data["ignoreErrorOrder"], message
      end
    end 
  end

  html5_test_files('tokenizer').each do |test_file|
    test_name = File.basename(test_file).sub('.test', '')

    tests = JSON.parse(File.read(test_file))['tests']

    tests.each_with_index do |data, index|
      define_method('test_%s_%d' % [test_name, index + 1]) { tokenizer_test data }
    end
  end

end

