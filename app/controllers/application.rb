require 'url_rewriting_hack'

# The filters added to this controller will be run for all controllers in the application.
# Likewise will all the methods added be available for all controllers.
class ApplicationController < ActionController::Base

  # implements Instiki's legacy URLs
  require 'url_rewriting_hack'

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
  
  def wiki
    $instiki_wiki_service
  end
  
end
