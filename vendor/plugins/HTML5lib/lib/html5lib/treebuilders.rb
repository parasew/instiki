module HTML5lib
  module TreeBuilders

    def self.getTreeBuilder(name)
      case name.to_s.downcase
        when 'simpletree' then
          require 'html5lib/treebuilders/simpletree'
          SimpleTree::TreeBuilder
        when 'rexml' then
          require 'html5lib/treebuilders/rexml'
          REXMLTree::TreeBuilder
        when 'hpricot' then
          require 'html5lib/treebuilders/hpricot'
          Hpricot::TreeBuilder
        else
          raise "Unknown TreeBuilder #{name}"
      end
    end

  end
end
