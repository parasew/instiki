require 'diff'
class Revision < ActiveRecord::Base
  belongs_to :page
  composed_of :author, :mapping => [ %w(author name), %w(ip ip) ]

  after_create :force_rendering

  def force_rendering
    PageRenderer.new(self).force_rendering
  end

end
