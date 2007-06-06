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
      json.gsub!(/"\s*:/, '"=>')
      json.gsub!(/\\u[0-9a-fA-F]{4}/) {|x| [x[2..-1].to_i(16)].pack('U')}
      eval json
    end
  end
end

module HTML5lib
  module TestSupport
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
      output.gsub(/^(\s+)\w+=.*(\n\1\w+=.*)+/) do |match|
         match.split("\n").sort.join("\n")
      end
    end

  end
end
