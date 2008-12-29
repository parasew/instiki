require_dependency 'cache_sweeping_helper'

class WebSweeper < ActionController::Caching::Sweeper

  include CacheSweepingHelper

  observe Web, Page
  
  def after_save(record)
    if record.is_a?(Web)
      web = record
      web.pages.each { |page| expire_cached_page(web, page.name) }
      expire_cached_summary_pages(web)
    end
  end

  def after_remove_orphaned_pages(web)
    expire_cached_summary_pages(web)
  end

  def after_remove_orphaned_pages_in_category(web)
    expire_cached_summary_pages(web)
  end
  
  def after_destroy(record)
    if record.is_a?(Web)
      expire_cached_summary_pages(record)
    else
      expire_cached_page(record.web, record.name)
    end
  end

end
