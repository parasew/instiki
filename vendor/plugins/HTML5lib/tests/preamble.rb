require 'test/unit'

HTML5LIB_BASE = File.dirname(File.dirname(File.dirname(File.expand_path(__FILE__))))

$:.unshift File.join(File.dirname(File.dirname(__FILE__)),'lib')

$:.unshift File.dirname(__FILE__)

def html5lib_test_files(subdirectory)
    Dir[File.join(HTML5LIB_BASE, 'tests', subdirectory, '*.*')]
end
