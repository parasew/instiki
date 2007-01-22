module WikiHelper

  def navigation_menu_for_revision
    menu = []
    menu << forward
    menu << back_for_revision if @revision_number > 1
    menu << current_revision
    menu << see_or_hide_changes_for_revision if @revision_number > 1
    menu << rollback
    menu
  end

  def navigation_menu_for_page
    menu = []
    menu << edit_page
    menu << edit_web if @page.name == "HomePage"
    if @page.revisions.length > 1
      menu << back_for_page
      menu << see_or_hide_changes_for_page
    end
    menu
  end

  def edit_page
    link_text = (@page.name == "HomePage" ? 'Edit Page' : 'Edit')
    link_to(link_text, {:web => @web.address, :action => 'edit', :id => @page.name}, 
        {:class => 'navlink', :accesskey => 'E', :name => 'edit'})
  end

  def edit_web
    link_to('Edit Web', {:web => @web.address, :action => 'edit_web'}, 
        {:class => 'navlink', :accesskey => 'W', :name => 'edit_web'})
  end
            
  def forward
    if @revision_number < @page.revisions.length - 1
      link_to('Forward in time', 
          {:web => @web.address, :action => 'revision', :id => @page.name, :rev => @revision_number + 1},
          {:class => 'navlink', :accesskey => 'F', :name => 'to_next_revision'}) + 
          " <small>(#{@revision.page.revisions.length - @revision_number} more)</small> "
    else
        link_to('Forward in time', {:web => @web.address, :action => 'show', :id => @page.name},
            {:class => 'navlink', :accesskey => 'F', :name => 'to_next_revision'}) +
            " <small> (to current)</small>"
    end
  end
    
  def back_for_revision
    link_to('Back in time',
        {:web => @web.address, :action => 'revision', :id => @page.name, :rev => @revision_number - 1},
        {:class => 'navlink', :name => 'to_previous_revision'}) + 
        " <small>(#{@revision_number - 1} more)</small>"
  end

  def back_for_page
    link_to('Back in time', 
        {:web => @web.address, :action => 'revision', :id => @page.name, 
        :rev => @page.revisions.length - 1},
        {:class => 'navlink', :accesskey => 'B', :name => 'to_previous_revision'}) +
        " <small>(#{@page.revisions.length - 1} #{@page.revisions.length - 1 == 1 ? 'revision' : 'revisions'})</small>"
  end
  
  def current_revision
    link_to('See current', {:web => @web.address, :action => 'show', :id => @page.name},
        {:class => 'navlink', :name => 'to_current_revision'})
  end
  
  def see_or_hide_changes_for_revision
    link_to(@show_diff ? 'Hide changes' : 'See changes', 
        {:web => @web.address, :action => 'revision', :id => @page.name, :rev => @revision_number, 
         :mode => (@show_diff ? nil : 'diff') },
        {:class => 'navlink', :accesskey => 'C', :name => 'see_changes'})
  end

  def see_or_hide_changes_for_page
    link_to(@show_diff ? 'Hide changes' : 'See changes', 
        {:web => @web.address, :action => 'show', :id => @page.name, :mode => (@show_diff ? nil : 'diff') },
        {:class => 'navlink', :accesskey => 'C', :name => 'see_changes'})
  end
  
  def rollback
    link_to('Rollback', 
        {:web => @web.address, :action => 'rollback', :id => @page.name, :rev => @revision_number},
        {:class => 'navlink', :name => 'rollback'})
  end

  

end