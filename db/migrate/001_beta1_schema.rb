class Beta1Schema < ActiveRecord::Migration
  def self.up
    create_table "pages", :force => true do |t|
      t.column "created_at", :datetime, :null => false
      t.column "updated_at", :datetime, :null => false
      t.column "web_id", :integer, :default => 0, :null => false
      t.column "locked_by", :string, :limit => 60
      t.column "name", :string, :limit => 60
      t.column "locked_at", :datetime
    end
  
    create_table "revisions", :force => true do |t|
      t.column "created_at", :datetime, :null => false
      t.column "updated_at", :datetime, :null => false
      t.column "revised_at", :datetime, :null => false
      t.column "page_id", :integer, :default => 0, :null => false
      t.column "content", :text
      t.column "author", :string, :limit => 60
      t.column "ip", :string, :limit => 60
    end
  
    create_table "system", :force => true do |t|
      t.column "password", :string, :limit => 60
    end
  
    create_table "webs", :force => true do |t|
      t.column "created_at", :datetime, :null => false
      t.column "updated_at", :datetime, :null => false
      t.column "name", :string, :limit => 60, :default => "", :null => false
      t.column "address", :string, :limit => 60, :default => "", :null => false
      t.column "password", :string, :limit => 60
      t.column "additional_style", :string
      t.column "allow_uploads", :integer, :default => 1
      t.column "published", :integer, :default => 0
      t.column "count_pages", :integer, :default => 0
      t.column "markup", :string, :limit => 50, :default => "markdownMML"
      t.column "color", :string, :limit => 6, :default => "008B26"
      t.column "max_upload_size", :integer, :default => 100
      t.column "safe_mode", :integer, :default => 0
      t.column "brackets_only", :integer, :default => 0
    end
  
    create_table "wiki_references", :force => true do |t|
      t.column "created_at", :datetime, :null => false
      t.column "updated_at", :datetime, :null => false
      t.column "page_id", :integer, :default => 0, :null => false
      t.column "referenced_name", :string, :limit => 60, :default => "", :null => false
      t.column "link_type", :string, :limit => 1, :default => "", :null => false
    end
  end

  def self.down
    raise 'Initial schema - cannot be further reverted'
  end

end
