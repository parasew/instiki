# The filters added to this controller will be run for all controllers in the application.
# Likewise will all the methods added be available for all controllers.
class ApplicationController < ActionController::Base

  protect_forms_from_spam
  before_filter :connect_to_model, :check_authorization, :setup_url_generator, :set_content_type_header, :set_robots_metatag
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

  helper_method :xhtml_enabled?, :html_ext, :darken

  protected

  def xhtml_enabled?
    in_a_web? and [:markdownMML, :markdownPNG, :markdown].include?(@web.markup)
  end

  def html_ext
    if xhtml_enabled? && request.env.include?('HTTP_ACCEPT') &&
           Mime::Type.parse(request.env["HTTP_ACCEPT"]).include?(Mime::XHTML)
       'xhtml'
    else
      'html'
    end       
  end

  def darken(s)
     n=s.length/3
     s.scan( %r(\w{#{n},#{n}}) ).collect {|a| (a.hex * 2/3).to_s(16).rjust(n,'0')}.join
  end

  def check_authorization
    if in_a_web? and authorization_needed? and not authorized?
      redirect_to :controller => 'wiki', :action => 'login', :web => @web_name
      return false
    end
  end

  def connect_to_model
    @action_name = params['action'] || 'index'
    @web_name = params['web']
    @wiki = wiki
    @author = cookies['author'] || 'AnonymousCoward'
    if @web_name
      @web = @wiki.webs[@web_name]
      if @web.nil?
        render(:status => 404, :text => "Unknown web '#{@web_name}'", :layout => 'error')
        return false 
      end
    end
  end

  FILE_TYPES = {
    '.aif' => 'audio/x-aiff',  
    '.aiff'=> 'audio/x-aiff',  
    '.avi' => 'video/x-msvideo',  
    '.exe' => 'application/octet-stream',
    '.gif' => 'image/gif',
    '.jpg' => 'image/jpeg',
    '.pdf' => 'application/pdf',
    '.png' => 'image/png',
    '.oga' => 'audio/ogg',
    '.ogg' => 'audio/ogg',
    '.ogv' => 'video/ogg',
    '.mov' => 'video/quicktime',
    '.mp3' => 'audio/mpeg',
    '.mp4' => 'video/mp4',
    '.spx' => 'audio/speex',
    '.txt' => 'text/plain',
    '.tex' => 'text/plain',
    '.wav' => 'audio/x-wav',
    '.zip' => 'application/zip'
  } unless defined? FILE_TYPES

  DISPOSITION = {
    'application/octet-stream' => 'attachment',
    'application/pdf'          => 'inline',
    'image/gif'                => 'inline',
    'image/jpeg'               => 'inline',
    'image/png'                => 'inline',
    'audio/mpeg'               => 'inline',
    'audio/x-wav'              => 'inline',
    'audio/x-aiff'             => 'inline',
    'audio/speex'             => 'inline',
    'audio/ogg'                => 'inline',
    'video/ogg'                => 'inline',
    'video/mp4'                => 'inline',
    'video/quicktime'          => 'inline',
    'video/x-msvideo'          => 'inline',
    'text/plain'               => 'inline',
    'application/zip'          => 'attachment'
  } unless defined? DISPOSITION
 
  def determine_file_options_for(file_name, original_options = {})
    original_options[:type] ||= (FILE_TYPES[File.extname(file_name)] or 'application/octet-stream')
    original_options[:disposition] ||= (DISPOSITION[original_options[:type]] or 'attachment')
    original_options[:stream] ||= false
    original_options[:x_sendfile] = true if request.env.include?('HTTP_X_SENDFILE_TYPE') &&
            ( request.remote_addr == LOCALHOST || defined?(PhusionPassenger) )
    original_options
  end
  
  def send_file(file, options = {})
    determine_file_options_for(file, options)
    super(file, options)
  end

  def password_check(password)
    if password == @web.password
      cookies[CGI.escape(@web_name)] = password
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
      redirect_to '/'
    end
  end

  def redirect_to_page(page_name = @page_name, web = @web_name)
    redirect_to :web => web, :controller => 'wiki', :action => 'show', 
        :id => (page_name or 'HomePage')
  end

  def remember_location
    if request.method == :get and 
        @status == '200' and not \
        %w(locked save back file pic import).include?(action_name)
      session[:return_to] = request.request_uri
      logger.debug "Session ##{session.object_id}: remembered URL '#{session[:return_to]}'"
    end
  end

  def rescue_action_in_public(exception)
      render :status => 500, :text => <<-EOL
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
          <h2>Internal Error</h2>
          <p>An application error occurred while processing your request.</p>
          <!-- \n#{exception.to_s.purify.gsub!(/-{2,}/, '- -') }\n#{exception.backtrace.join("\n")}\n -->
        </body></html>
      EOL
  end

  def return_to_last_remembered
    # Forget the redirect location
    redirect_target, session[:return_to] = session[:return_to], nil
    tried_home, session[:tried_home] = session[:tried_home], false

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
      redirect_to(redirect_target)
    end
  end

  def set_content_type_header
    response.charset = 'utf-8'
    if %w(atom_with_content atom_with_headlines).include?(action_name)
      response.content_type = Mime::ATOM
    elsif %w(tex tex_list).include?(action_name)
      response.content_type = Mime::TEXT
    elsif xhtml_enabled?
      if request.user_agent =~ /Validator/ or request.env.include?('HTTP_ACCEPT') &&
           Mime::Type.parse(request.env["HTTP_ACCEPT"]).include?(Mime::XHTML)  
        response.content_type = Mime::XHTML
      elsif request.user_agent =~ /MathPlayer/ 
        response.charset = nil
        response.content_type = Mime::XHTML
        response.extend(MathPlayerHack)
      else
        response.content_type = Mime::HTML
      end
    else
      response.content_type = Mime::HTML
    end
  end

  def set_robots_metatag
    if controller_name == 'wiki' and %w(show published s5).include? action_name and !(params[:mode] == 'diff')
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

  private

  def in_a_web?
    not @web_name.nil?
  end
  
  def authorization_needed?
    not %w(login authenticate feeds published atom_with_headlines atom_with_content file blahtex_png).include?(action_name)
  end

  def authorized?
    @web.nil? or
    @web.password.nil? or
    cookies[CGI.escape(@web_name)] == @web.password or
    password_check(params['password']) or
    (@web.published? and action_name == 's5')
  end

  def is_post
    unless (request.post? || Rails.env.test?)
      layout = 'error'
      layout = false if %w(tex tex_list).include?(action_name)
      headers['Allow'] = 'POST'
      render(:status => 405, :text => 'You must use an HTTP POST', :layout => layout)
      return false
    end
    return true
  end

end

module Mime
  # Fix HTML
  #HTML  = Type.new "text/html", :html, %w( application/xhtml+xml )
  self.class.const_set("HTML", Type.new("text/html", :html) )

  # Add XHTML
  XHTML  = Type.new "application/xhtml+xml", :xhtml
  
  # Fix xhtml and html lookups
  LOOKUP["text/html"]             = HTML
  LOOKUP["application/xhtml+xml"] = XHTML
end

module MathPlayerHack
    def charset=(encoding)
      self.headers["Content-Type"] = "#{content_type || Mime::HTML}"
    end
end

module Instiki
  module VERSION #:nodoc:
    MAJOR = 0
    MINOR = 19
    TINY  = 1 
    SUFFIX = '(MML+)'
    PRERELEASE =  false
    if PRERELEASE
       STRING = [MAJOR, MINOR].join('.') + PRERELEASE + SUFFIX
    else
       STRING = [MAJOR, MINOR, TINY].join('.') + SUFFIX
    end
  end
end

# Monkey patch, to make Hash#key work in Ruby 1.8
class Hash
  alias_method(:key, :index) unless method_defined?(:key)
end

# Monkey patch, to ensure ActionCache doesn't muck with the content-type header.
module ActionController #:nodoc:
  module Caching
    module Actions
      class ActionCacheFilter
        private
          def set_content_type!(controller, extension)
            return
          end
      end
    end
  end
end