RAILS_ENV = 'test'
require File.expand_path(File.join(File.dirname(__FILE__), '../../../../config/environment.rb'))
require 'action_controller/test_process'
require 'breakpoint'

class ProtectedController < ActionController::Base
  protect_forms_from_spam :only => :index
  def index
    if request.get?
      render :inline => form
    else
      render :text => 'Submission successful'
    end
  end
  
  def unprotected
    render :inline => form
  end
  
  private
  def form
    <<-EOD
    <% form_tag do %>
    	MyField: <%= text_field_tag 'testme' %>
    	<%= submit_tag %>
    <% end %>
    EOD
  end

end
