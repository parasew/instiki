class Page < ActiveRecord::Base
  belongs_to :web
  has_many :pages
end