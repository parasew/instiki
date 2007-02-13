require 'form_tag_helper_extensions'
module FormSpamProtection
  module ClassMethods
    def protect_forms_from_spam(*args)
      before_filter :protect_form_from_spam, *args
      before_filter :protect_form_handler_from_spam, *args
    end
  end

  def protect_form_from_spam
      @protect_form_from_spam = true
  end
  
  def protect_form_handler_from_spam
    unless request.get? || request.xml_http_request?
      if params[:_form_key] && session[:form_keys] && session[:form_keys].keys.include?(params[:_form_key])
        session[:form_keys][params[:_form_key]] += 1
        if session[:form_keys][params[:_form_key]] >= 4
          render :text => "You cannot resubmit this form again.", :layout => false, :status => 403
          return false
        end
      else
        render :text => "You must have Javascript on to submit this form.", :layout => false, :status => 403
        return false
      end
    end
  end
  
  extend ClassMethods
  
  def self.included(receiver)
    receiver.extend(ClassMethods)
  end
  
  
end