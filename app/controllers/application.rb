require 'url_rewriting_hack'

# The filters added to this controller will be run for all controllers in the application.
# Likewise will all the methods added be available for all controllers.
class ApplicationController < ActionController::Base

  # implements Instiki's legacy URLs
  require 'url_rewriting_hack'

  after_filter :remember_location

  # For injecting a different wiki model implementation. Intended for use in tests
  def self.wiki=(the_wiki)
    # a global variable is used here because Rails reloads controller and model classes in the 
    # development environment; therefore, storing it as a class variable does not work
    # class variable is, anyway, not much different from a global variable
    $instiki_wiki_service = the_wiki
    logger.debug("Wiki service: #{the_wiki.to_s}")
  end

  def self.wiki
    $instiki_wiki_service
  end

  protected
  
  def wiki
    $instiki_wiki_service
  end

  @@REMEMBER_NOT = []
  
  def remember_location
    if @response.headers['Status'] == '200 OK'
      @session[:return_to] = url_for unless @@REMEMBER_NOT.include? action_name
      @session[:already_tried_index_as_fallback] = false
    end
  end

  def return_to_last_remembered
    # Forget the redirect location
    redirect_target, @session[:return_to] = @session[:return_to], nil
    # then try to redirect to it
    if redirect_target.nil?
      raise 'Cannot redirect to index' if @session[:already_tried_index_as_fallback]
      @session[:already_tried_index_as_fallback] = true
      redirect_to_url '/'
    else
      redirect_to_url(redirect_target)
    end
  end

end
