# Create a route to DEFAULT_WEB, if such is specified; also register a generic route
def connect_to_web(generic_path, generic_routing_options)
  if defined? DEFAULT_WEB
    explicit_path = generic_path.gsub(/:web\/?/, '')
    explicit_routing_options = generic_routing_options.merge(:web => DEFAULT_WEB)
    match(explicit_path, explicit_routing_options)
  end
  match(generic_path, generic_routing_options)
end

# :id's can be arbitrary junk
  id_regexp = /.+/

Instiki::Application.routes.draw do
  match 'create_system', :to => 'admin#create_system'
  match 'create_web',    :to => 'admin#create_web'
  match 'delete_web',    :to => 'admin#delete_web'
  match 'delete_files',  :to => 'admin#delete_files'
  match 'web_list',      :to => 'wiki#web_list'

  connect_to_web ':web/edit_web',                          :to => 'admin#edit_web'
  connect_to_web ':web/remove_orphaned_pages',             :to => 'admin#remove_orphaned_pages'
  connect_to_web ':web/remove_orphaned_pages_in_category', :to => 'admin#remove_orphaned_pages_in_category'
  connect_to_web ':web/file/delete/:id',                   :to => 'file#delete',      :constraints => {:id => /[-._\w]+/}, :id => nil
  connect_to_web ':web/files/pngs/:id',                    :to => 'file#blahtex_png', :constraints => {:id => /[-._\w]+/}, :id => nil
  connect_to_web ':web/files/:id',                         :to => 'file#file',        :constraints => {:id => /[-._\w]+/}, :id => nil
  connect_to_web ':web/file_list/:sort_order',             :to => 'wiki#file_list',   :sort_order  => nil
  connect_to_web ':web/import/:id',                        :to => 'file#import'
  connect_to_web ':web/login',                             :to => 'wiki#login'
  connect_to_web ':web/web_list',                          :to => 'wiki#web_list'

  connect_to_web ':web/show/diff/:id',                     :to          => 'wiki#show',
                                                           :mode        => 'diff',
                                                           :constraints => {:id => id_regexp}

  connect_to_web ':web/revision/diff/:id/:rev',            :to          => 'wiki#revision',
                                                           :mode        => 'diff',
                                                           :constraints => { :rev => /\d+/, :id => id_regexp}

  connect_to_web ':web/revision/:id/:rev',                 :to => 'wiki#revision', :constraints => { :rev => /\d+/, :id => id_regexp}
  connect_to_web ':web/source/:id/:rev',                   :to => 'wiki#source',   :constraints => { :rev => /\d+/, :id => id_regexp}
  connect_to_web ':web/list/:category',                    :to => 'wiki#list',     :constraints => { :category => /.*/ }, :category => nil

  connect_to_web ':web/recently_revised/:category',        :to          => 'wiki#recently_revised',
                                                           :constraints => { :category => /.*/},
                                                           :category    => nil

  connect_to_web ':web/:action/:id',                       :to => 'wiki', :constraints => {:id => id_regexp}
  connect_to_web ':web/:action',                           :to => 'wiki'
  connect_to_web ':web',                                   :to => 'wiki#index'

  if defined? DEFAULT_WEB
    root :to => 'wiki#index', :web => DEFAULT_WEB
  else
    root :to => 'wiki#index'
  end
end
