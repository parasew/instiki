class System < ActiveRecord::Base
  set_table_name 'system'
  validates_presence_of :password
end