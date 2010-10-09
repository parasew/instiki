class AdminController < ApplicationController

  layout 'default'
  cache_sweeper :web_sweeper
  before_filter :dnsbl_check

  def create_system
    if @wiki.setup?
      flash[:error] = 
          "Wiki has already been created in '#{@wiki.storage_path}'. " +
          "Shut down Instiki and delete this directory if you want to recreate it from scratch." +
          "\n\n" +
          "(WARNING: this will destroy content of your current wiki)."
      redirect_home(@wiki.webs.keys.first)
    elsif params['web_name']
      # form submitted -> create a wiki
      @wiki.setup(params['password'], params['web_name'], params['web_address']) 
      flash[:info] = "Your new wiki '#{params['web_name']}' is created!\n" + 
          "Please edit its home page and press Submit when finished."
      redirect_to :web => params['web_address'], :controller => 'wiki', :action => 'new', 
          :id => 'HomePage'
    else
      # no form submitted -> go to template
    end
  end

  def create_web
    if params['address']
      return unless is_post
      # form submitted
      if @wiki.authenticate(params['system_password'])
        begin
          @wiki.create_web(params['name'], params['address'])
          flash[:info] = "New web '#{params['name']}' successfully created."
          redirect_to :web => params['address'], :controller => 'wiki', :action => 'new', 
              :id => 'HomePage'
        rescue Instiki::ValidationError => e
          @error = e.message
          # and re-render the form again
        end
      else
        flash[:error] = "System Password incorrect. Try again." 
        redirect_to :controller => 'admin', :action => 'create_web'
      end
    else
      # no form submitted -> render template
    end
  end

  def edit_web
    system_password = params['system_password']
    if system_password
      return unless is_post
      # form submitted
      if wiki.authenticate(system_password)
        begin
          raise Instiki::ValidationError.new("Password for this Web didn't match") unless
            (params['password'].empty? or params['password'] == params['password_check'])
          wiki.edit_web(
            @web.address, params['address'], params['name'], 
            params['markup'].intern, 
            params['color'], params['additional_style'], 
            params['safe_mode'] ? true : false, 
            params['password'].empty? ? nil : params['password'],
            params['published'] ? true : false, 
            params['brackets_only'] ? true : false,
            params['count_pages'] ? true : false,
            params['allow_uploads'] ? true : false,
            params['max_upload_size']
          )
          flash[:info] = "Web '#{params['address']}' was successfully updated"
          redirect_home(params['address'])
        rescue Instiki::ValidationError => e
          logger.warn e.message
          @error = e.message
          # and re-render the same template again
        end
      else
        @error = password_error(system_password)
        # and re-render the same template again
      end
    else
      # no form submitted - go to template
    end
  end

  def remove_orphaned_pages
    return unless is_post
    if wiki.authenticate(params['system_password_orphaned'])
      wiki.remove_orphaned_pages(@web_name)
      flash[:info] = 'Orphaned pages removed'
      redirect_to :controller => 'wiki', :web => @web_name, :action => 'list'
    else
      flash[:error] = password_error(params['system_password_orphaned'])
      redirect_to :controller => 'admin', :web => @web_name, :action => 'edit_web'
    end
  end
  
  def remove_orphaned_pages_in_category
    return unless is_post
    if wiki.authenticate(params['system_password_orphaned_in_category'])
      category = params['category']
      wiki.remove_orphaned_pages_in_category(@web_name, category)
      flash[:info] = "Orphaned pages in category \"#{category}\" removed"
      redirect_to :controller => 'wiki', :web => @web_name, :action => 'list'
    else
      flash[:error] = password_error(params['system_password_orphaned_in_category'])
      redirect_to :controller => 'admin', :web => @web_name, :action => 'edit_web'
    end
  end

  def delete_web
    return unless is_post
    if wiki.authenticate(params['system_password_delete_web'])
      wiki.delete_web(@web_name)
      flash[:info] = "Web \"#{@web_name}\" has been deleted."
      redirect_to :controller => 'wiki', :action => 'web_list'
    else
      flash[:error] = password_error(params['system_password_delete_web'])
      redirect_to :controller => 'admin', :web => @web_name, :action => 'edit_web'
    end  
  end
  
  def delete_files
    return unless is_post
    some_deleted = false
    if wiki.authenticate(params['system_password'])
      params.each do |file, p|
        if p == 'delete'
          WikiFile.find_by_file_name(file).destroy
          some_deleted = true
        end
      end
      flash[:info] = "File(s) successfully deleted." if some_deleted
    else
      flash[:error] = password_error(params['system_password'])
    end
    redirect_to :back
  end

end
