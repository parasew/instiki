Rails.application.routes.draw do
  # :id can be arbitrary junk (page names, file names with weird chars).
  id_re = /.+/

  # Helper that mirrors Rails-2-era connect_to_web: registers a per-:web route,
  # plus a default-web shortcut without :web prefix when DEFAULT_WEB is defined.
  def connect_to_web(generic_path, controller:, action: nil, via: [:get, :post], constraints: {}, defaults: {})
    target = action ? "#{controller}##{action}" : { controller: controller }
    opts = { via: via, constraints: constraints, defaults: defaults }
    opts[:to] = target if action
    opts[:controller] = controller unless action
    if defined?(DEFAULT_WEB)
      explicit_path = generic_path.gsub(/:web\/?/, "")
      explicit_opts = opts.dup
      explicit_opts[:defaults] = defaults.merge(web: DEFAULT_WEB)
      match explicit_path, **explicit_opts
    end
    match generic_path, **opts
  end

  # TeX → MathML Rack endpoint (see app/metal/itex.rb). Called by svg-edit.
  mount Itex => "/itex"

  # Top-level admin routes (no :web prefix).
  match "create_system",  to: "admin#create_system",  via: [:get, :post]
  match "create_web",     to: "admin#create_web",     via: [:get, :post]
  match "delete_web",     to: "admin#delete_web",     via: [:get, :post]
  match "delete_files",   to: "admin#delete_files",   via: [:get, :post]
  get   "web_list",       to: "wiki#web_list"

  connect_to_web ":web/edit_web",                           controller: "admin", action: "edit_web"
  connect_to_web ":web/remove_orphaned_pages",              controller: "admin", action: "remove_orphaned_pages"
  connect_to_web ":web/remove_orphaned_pages_in_category",  controller: "admin", action: "remove_orphaned_pages_in_category"
  connect_to_web ":web/file/delete/:id",                    controller: "file",  action: "delete",      constraints: { id: /[-._\w]+/ }
  connect_to_web ":web/files/pngs/:id",                     controller: "file",  action: "blahtex_png", constraints: { id: /[-._\w]+/ }
  connect_to_web ":web/files/:id",                          controller: "file",  action: "file",        constraints: { id: /[-._\w]+/ }
  connect_to_web ":web/file_list(/:sort_order)",            controller: "wiki",  action: "file_list"
  connect_to_web ":web/import(/:id)",                       controller: "file",  action: "import"
  connect_to_web ":web/login",                              controller: "wiki",  action: "login"
  connect_to_web ":web/web_list",                           controller: "wiki",  action: "web_list"
  # /show/diff/ and /revision/diff/ paths route to the same actions but with
  # a distinct internal action alias so url_for(action: 'show', ...) prefers
  # the plain /show/:id route. WikiController defines show_diff and
  # revision_diff that just set @show_diff and delegate to show / revision.
  connect_to_web ":web/show/diff/:id",                      controller: "wiki",  action: "show_diff",        constraints: { id: id_re }
  connect_to_web ":web/revision/diff/:id/:rev",             controller: "wiki",  action: "revision_diff",    constraints: { rev: /\d+/, id: id_re }
  connect_to_web ":web/revision/:id/:rev",                  controller: "wiki",  action: "revision",    constraints: { rev: /\d+/, id: id_re }
  # :id uses the greedy id_re (/.+/), which also matches "/".
  # Match the rev-bearing form first then fall back to the id-only form.
  connect_to_web ":web/source/:id/:rev",                    controller: "wiki",  action: "source",      constraints: { rev: /\d+/, id: id_re }
  connect_to_web ":web/source/:id",                         controller: "wiki",  action: "source",      constraints: { id: id_re }
  connect_to_web ":web/list(/:category)",                   controller: "wiki",  action: "list",        constraints: { category: /.*/ }
  connect_to_web ":web/recently_revised(/:category)",       controller: "wiki",  action: "recently_revised", constraints: { category: /.*/ }

  # Per-action wiki routes — Rails 7 removes the dynamic :action segment, so
  # we enumerate the actions explicitly. Same URL space as the old
  # :web/:action(/:id) fallback.
  %w[show edit save new history tex s5 print published locked cancel_edit].each do |a|
    connect_to_web ":web/#{a}(/:id)",                       controller: "wiki", action: a, constraints: { id: id_re }
  end
  connect_to_web ":web/rollback/:id/:rev",                  controller: "wiki", action: "rollback", constraints: { rev: /\d+/, id: id_re }
  %w[authenticate authors export export_html export_markup feeds
     atom_with_content atom_with_headlines atom_with_changes
     tex_list search].each do |a|
    connect_to_web ":web/#{a}",                             controller: "wiki", action: a
  end
  connect_to_web ":web",                                    controller: "wiki", action: "index"

  # Root URL.
  if defined?(DEFAULT_WEB)
    root to: "wiki#index", defaults: { web: DEFAULT_WEB }
  else
    root to: "wiki#index"
  end
end
