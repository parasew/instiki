module WikiHelper

  def navigation_menu_for_revision
    menu = []
    menu << forward
    menu << back_for_revision if @revision_number > 1
    menu << current_revision
    menu << see_or_hide_changes_for_revision if @revision_number > 1
    menu << history if @page.revisions.size > 1
    menu << rollback
    menu
  end

  def navigation_menu_for_page
    menu = []
    menu << edit_page
    menu << edit_web if @page.name == "HomePage"
    if @page.revisions.size > 1
      menu << back_for_page
      menu << see_or_hide_changes_for_page
    end
    menu << history if @page.revisions.size > 1
    menu
  end

  def edit_page
    link_text = (@page.name == "HomePage" ? 'Edit Page' : 'Edit')
    link_to(link_text, {:web => @web.address, :action => 'edit', :id => @page.name}, 
        {:class => 'navlink', :accesskey => 'E', :id => 'edit', :rel => 'nofollow'})
  end

  def edit_web
    link_to('Edit Web', {:web => @web.address, :action => 'edit_web'}, 
        {:class => 'navlink', :accesskey => 'W', :id => 'edit_web', :rel => 'nofollow'})
  end

  def history
    link_to_history(@page, 'History',
        {:class => 'navlink', :accesskey => 'S', :id => 'history', :rel => 'nofollow'})
  end
            
  def forward
    if @revision_number < @page.revisions.size - 1
      link_to('Forward in time', 
          {:web => @web.address, :action => 'revision', :id => @page.name, :rev => @revision_number + 1},
          {:class => 'navlink', :accesskey => 'F', :id => 'to_next_revision', :rel => 'nofollow'}) + 
          " <span class='revisions'>(#{@revision.page.revisions.size - @revision_number} more)</span> ".html_safe
    else
        link_to('Forward in time', {:web => @web.address, :action => 'show', :id => @page.name},
            {:class => 'navlink', :accesskey => 'F', :id => 'to_next_revision', :rel => 'nofollow'}) +
            " <span class='revisions'>(to current)</span>".html_safe
    end
  end
    
  def back_for_revision
    link_to('Back in time',
        {:web => @web.address, :action => 'revision', :id => @page.name, :rev => @revision_number - 1},
        {:class => 'navlink', :id => 'to_previous_revision', :rel => 'nofollow'}) + 
        " <span class='revisions'>(#{@revision_number - 1} more)</span>".html_safe
  end

  def back_for_page
    link_to('Back in time', 
        {:web => @web.address, :action => 'revision', :id => @page.name, 
        :rev => @page.revisions.size - 1},
        {:class => 'navlink', :accesskey => 'B', :id => 'to_previous_revision', :rel => 'nofollow'}) +
        " <span class='revisions'>(#{@page.revisions.size - 1} #{@page.revisions.size - 1 == 1 ? 'revision' : 'revisions'})</span>".html_safe
  end
  
  def current_revision
    link_to('See current', {:web => @web.address, :action => 'show', :id => @page.name},
        {:class => 'navlink', :id => 'to_current_revision'})
  end
  
  def see_or_hide_changes_for_revision
    link_to(@show_diff ? 'Hide changes' : 'See changes', 
        {:web => @web.address, :action => 'revision', :id => @page.name, :rev => @revision_number, 
         :mode => (@show_diff ? nil : 'diff') },
        {:class => 'navlink', :accesskey => 'C', :id => 'see_changes', :rel => 'nofollow'})
  end

  def see_or_hide_changes_for_page
    link_to(@show_diff ? 'Hide changes' : 'See changes', 
        {:web => @web.address, :action => 'show', :id => @page.name, :mode => (@show_diff ? nil : 'diff') },
        {:class => 'navlink', :accesskey => 'C', :id => 'see_changes', :rel => 'nofollow'})
  end
  
  def rollback
    link_to('Rollback', 
        {:web => @web.address, :action => 'rollback', :id => @page.name, :rev => @revision_number},
        {:class => 'navlink', :id => 'rollback', :rel => 'nofollow'})
  end

end
