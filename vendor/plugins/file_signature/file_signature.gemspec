Gem::Specification.new do |s|

  s.name              = "file_signature"
  s.summary           = "File signature adds the ability to inspect the first few bytes of a file to guess at mime-type."
  s.description       = "Monkeypatches File and IO to include a '''magic_number_type''' method which returns a symbol representing the mime type guessed based off of the first few bytes of a file."
  s.version           = "1.1.1"
  s.authors           = ["robacarp","SixArm"]
  s.email             = "coder@robacarp.com"
  s.homepage          = "http://github.com/robacarp/file_signature"

  s.platform          = Gem::Platform::RUBY
  s.require_path      = 'lib'

  CLASSES             = []
  TESTERS             = [
                         'sample.fit',
                         'sample.gif',
                         'sample.jpg',
                         'sample.png',
                         'sample.ps',
                         'sample.ras',
                         'sample.sgi',
                         'sample.tiff',
                         'sample.xcf.bz2',
                         'sample.xcf.gz'
                       ]

  top_files           = [".gemtest", "Rakefile", "README.md", "VERSION"]
  lib_files           = ["lib/#{s.name}.rb"]
  test_files          = ["test/#{s.name}_test.rb"] + TESTERS.map{|x| "test/#{s.name}_test/#{x}"}

  s.files             = top_files + lib_files + test_files
  s.test_files        = test_files
end
