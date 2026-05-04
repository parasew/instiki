# This class maintains the state of wiki references for newly created or newly deleted pages
class PageObserver < ActiveRecord::Observer
  
  def after_create(page)
    WikiReference.where(referenced_name: page.name)
                 .update_all(link_type: WikiReference::LINKED_PAGE)
  end

  def before_destroy(page)
    WikiReference.where(page_id: page.id).delete_all
    WikiReference.where(referenced_name: page.name)
                 .update_all(link_type: WikiReference::WANTED_PAGE)
  end

end