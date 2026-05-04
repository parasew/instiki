class System < ActiveRecord::Base
  self.table_name = 'system'
  validates_presence_of :password
end