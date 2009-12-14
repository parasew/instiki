require_dependency 'cache_sweeping_helper'

class RevisionSweeper < ActionController::Caching::Sweeper

  include CacheSweepingHelper
  
  observe Revision, Page
  
  def before_save(record)
    if record.is_a?(Revision)
      expire_cached_page(record.page.web, record.page.name) 
      expire_cached_revisions(record.page)
    end
  end
  
  def after_save(record)
    if record.is_a?(Revision)
      expire_caches(record.page)
    end
  end
  
  def after_delete(record)
    if record.is_a?(Page)
      expire_caches(record)
    end
  end
  
  private
  
  def expire_caches(page)
    expire_cached_summary_pages(page.web)
    pages_to_expire = ([page.name] + WikiReference.pages_that_reference(page.web, page.name) +
       WikiReference.pages_redirected_to(page.web, page.name) +
       WikiReference.pages_that_include(page.web, page.name)).uniq
    pages_to_expire.each { |page_name| expire_cached_page(page.web, page_name) }
  end

end
