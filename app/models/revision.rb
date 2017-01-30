class Revision < ActiveRecord::Base
  belongs_to :page
  composed_of :author, :mapping => [ %w(author name), %w(ip ip) ]

  attr_accessible :revised_at, :page, :content, :author

  def content
    read_attribute(:content).as_utf8
  end

  def number
    hash = Hash[self.page.revisions.map.with_index.to_a]
    return hash[self] + 1
  end
end
