# This class maintains the state of wiki references for newly created or newly deleted pages
class PageObserver < ActiveRecord::Observer
  
  def after_create(page)
    WikiReference.update_all("link_type = '#{WikiReference::LINKED_PAGE}'", 
        ['referenced_name = ?', page.name])
  end

  def before_destroy(page)
    WikiReference.delete_all ['page_id = ?', page.id]
    WikiReference.update_all("link_type = '#{WikiReference::WANTED_PAGE}'", 
        ['referenced_name = ?', page.name])
  end

end