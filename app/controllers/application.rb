# The filters added to this controller will be run for all controllers in the application.
# Likewise will all the methods added be available for all controllers.
class ApplicationController < ActionController::Base

  before_filter :connect_to_model, :setup_url_generator, :set_content_type_header, :set_robots_metatag
  after_filter :remember_location, :teardown_url_generator

  # For injecting a different wiki model implementation. Intended for use in tests
  def self.wiki=(the_wiki)
    # a global variable is used here because Rails reloads controller and model classes in the 
    # development environment; therefore, storing it as a class variable does not work
    # class variable is, anyway, not much different from a global variable
    #$instiki_wiki_service = the_wiki
    logger.debug("Wiki service: #{the_wiki.to_s}")
  end

  def self.wiki
    Wiki.new
  end

  protected
  
  def authorized?
    @web.nil? ||
    @web.password.nil? || 
    cookies['web_address'] == @web.password || 
    password_check(@params['password'])
  end

  def check_authorization
    if in_a_web? and needs_authorization?(@action_name) and not authorized? and 
      redirect_to :controller => 'wiki', :action => 'login', :web => @web_name
      return false
    end
  end

  def connect_to_model
    @action_name = @params['action'] || 'index'
    @web_name = @params['web']
    @wiki = wiki
    if @web_name
      @web = @wiki.webs[@web_name] 
      if @web.nil?
        render_text "Unknown web '#{@web_name}'", '404 Not Found'
        return false
      end
    end
    @page_name = @file_name = @params['id']
    @page = @wiki.read_page(@web_name, @page_name) unless @page_name.nil?
    @author = cookies['author'] || 'AnonymousCoward'
    check_authorization
  end

  FILE_TYPES = {
    '.exe' => 'application/octet-stream',
    '.gif' => 'image/gif',
    '.jpg' => 'image/jpeg',
    '.pdf' => 'application/pdf',
    '.png' => 'image/png',
    '.txt' => 'text/plain',
    '.zip' => 'application/zip'
  } unless defined? FILE_TYPES

  def send_file(file, options = {})
    options[:type] ||= (FILE_TYPES[File.extname(file)] || 'application/octet-stream')
    options[:stream] = false
    super(file, options)
  end

  def in_a_web?
    not @web_name.nil?
  end

  def password_check(password)
    if password == @web.password
      cookies['web_address'] = password
      true
    else
      false
    end
  end

  def password_error(password)
    if password.nil? or password.empty?
      'Please enter the password.'
    else 
      'You entered a wrong password. Please enter the right one.'
    end
  end

  def redirect_home(web = @web_name)
    if web
      redirect_to_page('HomePage', web)
    else
      redirect_to_url '/'
    end
  end

  def redirect_to_page(page_name = @page_name, web = @web_name)
    redirect_to :web => web, :controller => 'wiki', :action => 'show', 
        :id => (page_name || 'HomePage')
  end

  @@REMEMBER_NOT = ['locked', 'save', 'back', 'file', 'pic', 'import']
  def remember_location
    if @response.headers['Status'] == '200 OK'
      unless @@REMEMBER_NOT.include? action_name or @request.method != :get
        @session[:return_to] = @request.request_uri
        logger.debug("Session ##{session.object_id}: remembered URL '#{@session[:return_to]}'")
      end
    end
  end

  def rescue_action_in_public(exception)
    message = <<-EOL
      <html><body>
        <h2>Internal Error 500</h2>
        <p>An application error occurred while processing your request.</p>
        <!-- \n#{exception}\n#{exception.backtrace.join("\n")}\n  -->
      </body></html>
    EOL
    render_text message, 'Internal Error 500'
  end

  def return_to_last_remembered
    # Forget the redirect location
    redirect_target, @session[:return_to] = @session[:return_to], nil
    tried_home, @session[:tried_home] = @session[:tried_home], false

    # then try to redirect to it
    if redirect_target.nil?
      if tried_home
        raise 'Application could not render the index page'
      else
        logger.debug("Session ##{session.object_id}: no remembered redirect location, trying home")
        redirect_home
      end
    else
      logger.debug("Session ##{session.object_id}: " +
          "redirect to the last remembered URL #{redirect_target}")
      redirect_to_url(redirect_target)
    end
  end

  def set_content_type_header
    if %w(rss_with_content rss_with_headlines).include?(action_name)
      @response.headers['Content-Type'] = 'text/xml; charset=UTF-8'
    else
      @response.headers['Content-Type'] = 'text/html; charset=UTF-8'
    end
  end

  def set_robots_metatag
    if controller_name == 'wiki' and %w(show published).include? action_name 
      @robots_metatag_value = 'index,follow'
    else
      @robots_metatag_value = 'noindex,nofollow'
    end
  end

  def setup_url_generator
    PageRenderer.setup_url_generator(UrlGenerator.new(self))
  end

  def teardown_url_generator
    PageRenderer.teardown_url_generator
  end

  def wiki
    self.class.wiki
  end

  def needs_authorization?(action)
    not %w( login authenticate published rss_with_content rss_with_headlines ).include?(action)
  end

end
