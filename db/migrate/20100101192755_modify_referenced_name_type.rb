class ModifyReferencedNameType < ActiveRecord::Migration
  def self.up
    change_column :wiki_references, :referenced_name, :string, :limit => 255
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
