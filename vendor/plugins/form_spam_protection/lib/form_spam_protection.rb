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
      if params[:_form_key] && session[:form_keys] 
        key = Digest::SHA1.hexdigest(params[:_form_key])
        if session[:form_keys].keys.include?(key)
          session[:form_keys][key][1] += 1
          if session[:form_keys][key][1] >= 4
            render :text => "You cannot resubmit this form again.", :layout => 'error', :status => 403
            return false
          end
        end
      else
        render :text => "You must have Javascript on, and cookies enabled, to submit this form.", :layout => 'error', :status => 403
        return false
      end
    end
  end
  
  extend ClassMethods
  
  def self.included(receiver)
    receiver.extend(ClassMethods)
  end
  
  
end
