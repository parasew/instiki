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

    ([page.name] + WikiReference.pages_that_reference(page.name)).uniq.each do |page_name|
      expire_action :controller => 'wiki', :web => web.address,
          :action => %w(show published), :id => page_name
    end

    categories = WikiReference.find(:all, :conditions => "link_type = 'C'")
    %w(recently_revised list).each do |action|
      expire_action :controller => 'wiki', :web => web.address, :action => action
      categories.each do |category|
        expire_action :controller => 'wiki', :web => web.address, :action => action, :category => category.referenced_name
      end
    end

    expire_action :controller => 'wiki', :web => web.address, :action => 'authors'
    expire_fragment :controller => 'wiki', :web => web.address, :action => %w(rss_with_headlines rss_with_content)
  end

end
