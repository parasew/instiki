require 'application'

class AdminController < ApplicationController

  layout 'default'

  def create_system
    if @wiki.setup?
      flash[:error] = 
          "Wiki has already been created in '#{@wiki.storage_path}'. " +
          "Shut down Instiki and delete this directory if you want to recreate it from scratch." +
          "\n\n" +
          "(WARNING: this will destroy content of your current wiki)."
      redirect_home(@wiki.webs.keys.first)
    elsif @params['web_name']
      # form submitted -> create a wiki
      @wiki.setup(@params['password'], @params['web_name'], @params['web_address']) 
      flash[:info] = "Your new wiki '#{@params['web_name']}' is created!\n" + 
          "Please edit its home page and press Submit when finished."
      redirect_to :web => @params['web_address'], :controller => 'wiki', :action => 'new', 
          :id => 'HomePage'
    else
      # no form submitted -> go to template
    end
  end

  def create_web
    if @params['address']
      # form submitted
      if @wiki.authenticate(@params['system_password'])
        begin
          @wiki.create_web(@params['name'], @params['address'])
          flash[:info] = "New web '#{@params['name']}' successfully created."
          redirect_to :web => @params['address'], :controller => 'wiki', :action => 'new', 
              :id => 'HomePage'
        rescue Instiki::ValidationError => e
          @error = e.message
          # and re-render the form again
        end
      else 
        redirect_to :controller => 'wiki', :action => 'index'
      end
    else
      # no form submitted -> render template
    end
  end

  def edit_web

    system_password = @params['system_password']
    if system_password
      # form submitted
      if wiki.authenticate(system_password)
        begin
          wiki.edit_web(
            @web.address, @params['address'], @params['name'], 
            @params['markup'].intern, 
            @params['color'], @params['additional_style'], 
            @params['safe_mode'] ? true : false, 
            @params['password'].empty? ? nil : @params['password'],
            @params['published'] ? true : false, 
            @params['brackets_only'] ? true : false,
            @params['count_pages'] ? true : false,
            @params['allow_uploads'] ? true : false,
            @params['max_upload_size']
          )
          flash[:info] = "Web '#{@params['address']}' was successfully updated"
          redirect_home(@params['address'])
        rescue Instiki::ValidationError => e
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
    if wiki.authenticate(@params['system_password_orphaned'])
      wiki.remove_orphaned_pages(@web_name)
      flash[:info] = 'Orphaned pages removed'
      redirect_to :controller => 'wiki', :web => @web_name, :action => 'list'
    else
      flash[:error] = password_error(@params['system_password_orphaned'])
      redirect_to :controller => 'admin', :web => @web_name, :action => 'edit_web'
    end
  end

end
