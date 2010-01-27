# Create a route to DEFAULT_WEB, if such is specified; also register a generic route
def connect_to_web(map, generic_path, generic_routing_options)
  if defined? DEFAULT_WEB
    explicit_path = generic_path.gsub(/:web\/?/, '')
    explicit_routing_options = generic_routing_options.merge(:web => DEFAULT_WEB)
    map.connect(explicit_path, explicit_routing_options)
  end
  map.connect(generic_path, generic_routing_options)
end

# :id's can be arbitrary junk
  id_regexp = /.+/

ActionController::Routing::Routes.draw do |map|
  map.connect 'create_system', :controller => 'admin', :action => 'create_system'
  map.connect 'create_web', :controller => 'admin', :action => 'create_web'
  map.connect 'delete_web', :controller => 'admin', :action => 'delete_web'
  map.connect 'delete_files', :controller => 'admin', :action => 'delete_files'
  map.connect 'web_list', :controller => 'wiki', :action => 'web_list'

  connect_to_web map, ':web/edit_web', :controller => 'admin', :action => 'edit_web'
  connect_to_web map, ':web/remove_orphaned_pages', :controller => 'admin', :action => 'remove_orphaned_pages'
  connect_to_web map, ':web/remove_orphaned_pages_in_category', :controller => 'admin', :action => 'remove_orphaned_pages_in_category'
  connect_to_web map, ':web/file/delete/:id', :controller => 'file', :action => 'delete', :requirements => {:id => /[-._\w]+/}, :id => nil
  connect_to_web map, ':web/files/pngs/:id', :controller => 'file', :action => 'blahtex_png', :requirements => {:id => /[-._\w]+/}, :id => nil
  connect_to_web map, ':web/files/:id', :controller => 'file', :action => 'file', :requirements => {:id => /[-._\w]+/}, :id => nil
  connect_to_web map, ':web/file_list/:sort_order', :controller => 'wiki', :action => 'file_list', :sort_order => nil
  connect_to_web map, ':web/import/:id', :controller => 'file', :action => 'import'
  connect_to_web map, ':web/login', :controller => 'wiki', :action => 'login'
  connect_to_web map, ':web/web_list', :controller => 'wiki', :action => 'web_list'
  connect_to_web map, ':web/show/diff/:id', :controller => 'wiki', :action => 'show', :mode => 'diff', :requirements => {:id => id_regexp}
  connect_to_web map, ':web/revision/diff/:id/:rev', :controller => 'wiki', :action => 'revision', :mode => 'diff',
       :requirements => { :rev => /\d+/, :id => id_regexp}
  connect_to_web map, ':web/revision/:id/:rev', :controller => 'wiki', :action => 'revision', :requirements => { :rev => /\d+/, :id => id_regexp}
  connect_to_web map, ':web/list/:category', :controller => 'wiki', :action => 'list', :requirements => { :category => /.*/}, :category => nil
  connect_to_web map, ':web/recently_revised/:category', :controller => 'wiki', :action => 'recently_revised', :requirements => { :category => /.*/}, :category => nil
  connect_to_web map, ':web/:action/:id', :controller => 'wiki', :requirements => {:id => id_regexp}
  connect_to_web map, ':web/:action', :controller => 'wiki'
  connect_to_web map, ':web', :controller => 'wiki', :action => 'index'

  if defined? DEFAULT_WEB
    map.connect '', :controller => 'wiki', :web => DEFAULT_WEB, :action => 'index'
  else
    map.connect '', :controller => 'wiki', :action => 'index'
  end
end
