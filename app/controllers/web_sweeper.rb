require_dependency 'cache_sweeping_helper'

class WebSweeper < ActionController::Caching::Sweeper

  include CacheSweepingHelper

  observe Web, Page, WikiFile
  
  def after_save(record)
    if record.is_a?(Web)
      web = record
      web.pages.each { |page| expire_cached_page(web, page.name) }
      expire_cached_summary_pages(web)
    elsif record.is_a?(WikiFile)
      record.web.pages_that_link_to(record.file_name).each do |page|
        expire_cached_page(record.web, page)
      end
      expire_cached_summary_pages(record.web)
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
    elsif record.is_a?(Page)
      expire_cached_page(record.web, record.name)
      expire_cached_summary_pages(record.web)
    else
      expire_cached_summary_pages(record.web)
    end
  end

end
