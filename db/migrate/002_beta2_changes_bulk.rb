class Beta2ChangesBulk < ActiveRecord::Migration
  def self.up
    add_index "revisions", "page_id"
    add_index "revisions", "created_at"
    add_index "revisions", "author"
    
    create_table "sessions", :force => true do |t|
      t.column "session_id", :string
      t.column "data", :text
      t.column "updated_at", :datetime
    end
    add_index "sessions", "session_id"
    
    create_table "wiki_files", :force => true do |t|
      t.column "created_at", :datetime, :null => false
      t.column "updated_at", :datetime, :null => false
      t.column "web_id", :integer, :null => false
      t.column "file_name", :string, :null => false
      t.column "description", :string, :null => false
    end

    add_index "wiki_references", "page_id"
    add_index "wiki_references", "referenced_name"
  end

  def self.down
    remove_index "wiki_references", "referenced_name"
    remove_index "wiki_references", "page_id"
    drop_table "wiki_files"
    remove_index "sessions", "session_id"
    drop_table "sessions"
    remove_index "revisions", "author"
    remove_index "revisions", "created_at"
    remove_index "revisions", "page_id"
  end
end
