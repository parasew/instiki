require 'test_helper'
require 'find'

test_root = File.dirname(__FILE__)
Find.find(test_root) { |path| 
  if File.file?(path) and path =~ /.*_test\.rb$/
    load path
  end
}
