require_dependency 'cache_sweeping_helper'

class RevisionSweeper < ActionController::Caching::Sweeper

  include CacheSweepingHelper

  observe Revision, Page

  def before_save(record)
    if record.is_a?(Revision) and !@will_expire
      @will_expire = record.page.name
    end
  end

  def after_commit(record)
    if record.is_a?(Revision) and @will_expire
      expire_cached_revisions(record.page)
      expire_caches(record.page)
      @will_expire = nil
    end
  end

  def after_create(record)
    if record.is_a?(Page)
      WikiReference.pages_that_reference(record.web, record.name).each do |page_name|
        expire_cached_page(record.web, page_name)
      end
    end
  end

  def after_delete(record)
    if record.is_a?(Page)
      expire_cached_revisions(record)
      expire_caches(record)
    end
  end

  def self.expire_page(web, page_name)
    new.expire_cached_page(web, page_name)
  end

  private

  def expire_caches(page)
    expire_cached_summary_pages(page.web)
    pages_to_expire = [page.name] +
       WikiReference.pages_redirected_to(page.web, @will_expire) +
       WikiReference.pages_that_include(page.web, @will_expire)
    unless (page.name == @will_expire)
      pages_to_expire.concat ([@will_expire] +
        WikiReference.pages_that_link_to(page.web, @will_expire) +
        WikiReference.pages_that_reference(page.web, page.name))
    end
    pages_to_expire.uniq.each { |page_name| expire_cached_page(page.web, page_name) }
  end

end
