class ModifyTextTypes < ActiveRecord::Migration[7.0]
  def self.up
    unless adapter_name.eql?('PostgreSQL')
      change_column :revisions, :content, :text, :limit => 16777215
    end
    change_column :pages, :name, :string, :limit => 255
    change_column :webs, :additional_style, :text
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
