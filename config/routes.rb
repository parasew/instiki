ActionController::Routing.draw do |map|
  map.connect 'create_system', :controller => 'admin', :action => 'create_system'
  map.connect 'create_web', :controller => 'admin', :action => 'create_web'
  map.connect ':web/edit_web', :controller => 'admin', :action => 'edit_web'
  map.connect 'remove_orphaned_pages', :controller => 'admin', :action => 'remove_orphaned_pages'

  map.connect ':web/file/:id', :controller => 'file', :action => 'file'
  map.connect ':web/pic/:id', :controller => 'file', :action => 'pic'
  map.connect ':web/import/:id', :controller => 'file', :action => 'import'

  map.connect ':web/login', :controller => 'wiki', :action => 'login'
  map.connect 'web_list', :controller => 'wiki', :action => 'web_list'
  map.connect ':web/web_list', :controller => 'wiki', :action => 'web_list'
  map.connect ':web/:action/:id', :controller => 'wiki'
  map.connect ':web/:action', :controller => 'wiki'
  map.connect ':web', :controller => 'wiki', :action => 'index'
  map.connect '', :controller => 'wiki', :action => 'index'
end
