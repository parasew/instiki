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
    web = page.web
    expire_action :controller => 'wiki', :web => web.address,
        :action => %w(show published), :id => page.name
    expire_action :controller => 'wiki', :web => web.address,
        :action => %w(authors recently_revised list)
    expire_fragment :controller => 'wiki', :web => web.address,
        :action => %w(rss_with_headlines rss_with_content)
    WikiReference.pages_that_reference(page.name).each do |ref|
      expire_action :controller => 'wiki', :web => web.address,
          :action => %w(show published), :id => ref.page.name
    end
  end
end