class Revision < ActiveRecord::Base
  belongs_to :page
  composed_of :author, :mapping => [ %w(author name), %w(ip ip) ]

  def content
    read_attribute(:content).as_utf8
  end
end
