require 'application'

class AdminController < ApplicationController

  layout 'default'

  def create_system
    @wiki.setup(@params['password'], @params['web_name'], @params['web_address']) unless @wiki.setup?
    redirect_show('HomePage', @params['web_address'])
  end

  def create_web
    if @wiki.authenticate(@params['system_password'])
      @wiki.create_web(@params['name'], @params['address'])
      redirect_show('HomePage', @params['address'])
    else 
      redirect_to :action => 'index'
    end
  end

  def edit_web
    # to template
  end

  def new_system
    redirect_to(:action => 'index') if wiki.setup?
    # otherwise, to template
  end
  
  def new_web
    redirect_to :action => 'index' if wiki.system['password'].nil?
    # otherwise, to template
  end

  def update_web
    if wiki.authenticate(@params['system_password'])
      wiki.update_web(
        @web.address, @params['address'], @params['name'], 
        @params['markup'].intern, 
        @params['color'], @params['additional_style'], 
        @params['safe_mode'] ? true : false, 
        @params['password'].empty? ? nil : @params['password'],
        @params['published'] ? true : false, 
        @params['brackets_only'] ? true : false,
        @params['count_pages'] ? true : false,
        @params['allow_uploads'] ? true : false
      )
      redirect_show('HomePage', @params['address'])
    else
      redirect_show('HomePage') 
    end
  end

end
