require 'html5/treewalkers/base'

module HTML5
  module TreeWalkers

    class << self
      def [](name)
        case name.to_s.downcase
        when 'simpletree'
          require 'html5/treewalkers/simpletree'
          SimpleTree::TreeWalker
        when 'rexml'
          require 'html5/treewalkers/rexml'
          REXML::TreeWalker
        when 'hpricot'
          require 'html5/treewalkers/hpricot'
          Hpricot::TreeWalker
        else
          raise "Unknown TreeWalker #{name}"
        end
      end

      alias :get_tree_walker :[]
    end
  end
end
