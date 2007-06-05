require 'test/unit'

HTML5LIB_BASE = File.dirname(File.dirname(File.dirname(File.expand_path(__FILE__))))

$:.unshift File.join(File.dirname(File.dirname(__FILE__)),'lib')

$:.unshift File.dirname(__FILE__)

def html5lib_test_files(subdirectory)
  Dir[File.join(HTML5LIB_BASE, 'tests', subdirectory, '*.*')]
end

begin
  require 'jsonx'
rescue LoadError
  class JSON
    def self.parse json
      json.gsub! /"\s*:/, '"=>'
      json.gsub!(/\\u[0-9a-fA-F]{4}/) {|x| [x[2..-1].to_i(16)].pack('U')}
      eval json
    end
  end
end
