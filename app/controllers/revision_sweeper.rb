class RevisionSweeper < ActionController::Caching::Sweeper
  observe Revision, Page
  
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
    expire_page :controller => 'wiki', :web => page.web.address,
        :action => %w(show published), :id => page.name
    expire_page :controller => 'wiki', :web => page.web.address,
        :action => %w(authors recently_revised list rss_with_content rss_with_headlines)
  end
end
