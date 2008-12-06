require_dependency 'cache_sweeping_helper'

class WebSweeper < ActionController::Caching::Sweeper

  include CacheSweepingHelper

  observe Web
  
  def after_save(record)
    web = record
    web.pages.each { |page| expire_cached_page(web, page.name) }
    expire_cached_summary_pages(web)
  end

  def after_remove_orphaned_pages(web)
    expire_cached_summary_pages(web)
  end

  def after_remove_orphaned_pages_in_category(web)
    expire_cached_summary_pages(web)
  end

end
