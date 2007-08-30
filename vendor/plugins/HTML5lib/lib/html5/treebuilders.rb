module HTML5
  module TreeBuilders

    class << self
      def [](name)
        case name.to_s.downcase
        when 'simpletree' then
          require 'html5/treebuilders/simpletree'
          SimpleTree::TreeBuilder
        when 'rexml' then
          require 'html5/treebuilders/rexml'
          REXML::TreeBuilder
        when 'hpricot' then
          require 'html5/treebuilders/hpricot'
          Hpricot::TreeBuilder
        else
          raise "Unknown TreeBuilder #{name}"
        end
      end

      alias :get_tree_builder :[]
    end
  end
end
