module CacheSweepingHelper
  
  def expire_cached_page(web, page_name)
    expire_action :controller => 'wiki', :web => web.address,
        :action => %w(show published), :id => page_name
  end

  def expire_cached_summary_pages(web)
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