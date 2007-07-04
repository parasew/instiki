require 'html5/treewalkers/base'

module HTML5
  module TreeWalkers

    class << self
      def [](name)
        case name.to_s.downcase
        when 'simpletree' then
          require 'html5/treewalkers/simpletree'
          SimpleTree::TreeWalker
        when 'rexml' then
          require 'html5/treewalkers/rexml'
          REXML::TreeWalker
        when 'hpricot' then
          require 'html5/treewalkers/hpricot'
          Hpricot::TreeWalker
        else
          raise "Unknown TreeWalker #{name}"
        end
      end

      alias :getTreeWalker :[]
    end
  end
end
