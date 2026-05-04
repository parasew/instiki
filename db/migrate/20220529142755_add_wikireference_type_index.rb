class AddWikireferenceTypeIndex < ActiveRecord::Migration[7.0]
  def self.up
    add_index :wiki_references, :link_type, :name => "index_wiki_references_on_link_type"
  end

  def self.down
    remove_index :wiki_references, :name => "index_wiki_references_on_link_type"
  end
end
