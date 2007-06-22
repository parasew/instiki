require 'html5lib/treewalkers/base'

module HTML5lib
  module TreeWalkers

    class << self
      def [](name)
        case name.to_s.downcase
        when 'simpletree' then
          require 'html5lib/treewalkers/simpletree'
          SimpleTree::TreeWalker
        when 'rexml' then
          require 'html5lib/treewalkers/rexml'
          REXML::TreeWalker
        when 'hpricot' then
          require 'html5lib/treewalkers/hpricot'
          Hpricot::TreeWalker
        else
          raise "Unknown TreeWalker #{name}"
        end
      end

      alias :getTreeWalker :[]
    end
  end
end
