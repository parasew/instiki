#!/usr/bin/env ruby -wKU

require File.join(File.dirname(__FILE__), 'preamble')

require 'html5'
require 'html5/filters/validator'

class TestValidator < Test::Unit::TestCase
  def run_validator_test(test)
    p = HTML5::HTMLParser.new(:tokenizer => HTMLConformanceChecker)
    p.parse(test['input'])
    errorCodes = p.errors.collect{|e| e[1]}
    if test.has_key?('fail-if')
      assert !errorCodes.include?(test['fail-if'])
    end
    if test.has_key?('fail-unless')
      assert errorCodes.include?(test['fail-unless'])
    end
  end

  for filename in html5_test_files('validator')
    tests    = JSON.load(open(filename))
    testName = File.basename(filename).sub(".test", "")
    tests['tests'].each_with_index do |test, index|
      define_method "test_#{testName}_#{index}" do
        run_validator_test(test)
      end
    end
  end
end

