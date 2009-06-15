require 'fileutils'
require 'maruku'
require 'zip/zip'
require 'stringsupport'
require 'resolv'

class WikiController < ApplicationController

  before_filter :load_page
  before_filter :dnsbl_check, :only => [:edit, :new, :save, :export_html, :export_markup]
  caches_action :show, :published, :authors, :tex, :s5, :print, :recently_revised, :list, :file_list,
        :history, :revision, :atom_with_content, :atom_with_headlines, :if => Proc.new { |c| c.send(:do_caching?) }
  cache_sweeper :revision_sweeper

  layout 'default', :except => [:atom_with_content, :atom_with_headlines, :atom, :tex, :s5, :export_html]

  def index
    if @web_name
      redirect_home
    elsif not @wiki.setup?
      redirect_to :controller => 'admin', :action => 'create_system'
    elsif @wiki.webs.length == 1
      redirect_home @wiki.webs.values.first.address
    else
      redirect_to :action => 'web_list'
    end
  end

  # Outside a single web --------------------------------------------------------

  def authenticate
    if password_check(params['password'])
      redirect_home
    else 
      flash[:info] = password_error(params['password'])
      redirect_to :action => 'login', :web => @web_name
    end
  end

  def login
    # to template
  end
  
  def web_list
    @webs = wiki.webs.values.sort_by { |web| web.name }
  end


  # Within a single web ---------------------------------------------------------

  def authors
    @page_names_by_author = @web.page_names_by_author
    @authors = @page_names_by_author.keys.sort
  end
  
  def file_list
    sort_order = params['sort_order'] || 'file_name'
    case sort_order
      when 'file_name'
        @alt_sort_order = 'created_at'
        @alt_sort_name = 'date'
      else
        @alt_sort_order = 'file_name'
        @alt_sort_name = 'filename'
    end
    @file_list = @web.file_list(sort_order)
  end
  
  def export_html
    stylesheet = File.read(File.join(RAILS_ROOT, 'public', 'stylesheets', 'instiki.css'))
    export_pages_as_zip(html_ext) do |page| 

      renderer = PageRenderer.new(page.revisions.last)
      rendered_page = <<-EOL
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1 plus MathML 2.0 plus SVG 1.1//EN" "http://www.w3.org/2002/04/xhtml-math-svg/xhtml-math-svg-flat.dtd" >
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <title>#{page.plain_name} in #{@web.name}</title>
          <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  
          <style type="text/css">
            h1#pageName, .newWikiWord a, a.existingWikiWord, .newWikiWord a:hover { 
              color: ##{@web ? @web.color : "393" }; 
            }
            .newWikiWord { background-color: white; font-style: italic; }
            #{stylesheet}
          </style>
          <style type="text/css">
            #{@web.additional_style}
          </style>
        </head>
        <body>
          <h1 id="pageName">
            <span class="webName">#{@web.name}</span><br />
            #{page.plain_name}    
          </h1>
          #{renderer.display_content_for_export}
          <div class="byline">
            #{page.revisions? ? "Revised" : "Created" } on #{ page.revised_at.strftime('%B %d, %Y %H:%M:%S') }
            by
            #{ UrlGenerator.new(self).make_link(page.author.name, @web, nil, { :mode => :export }) }
          </div>
        </body>
        </html>
      EOL
      rendered_page
    end
  end

  def export_markup
    export_pages_as_zip(@web.markup) { |page| page.content }
  end

#  def export_pdf
#    file_name = "#{@web.address}-tex-#{@web.revised_at.strftime('%Y-%m-%d-%H-%M-%S')}"
#    file_path = File.join(@wiki.storage_path, file_name)
#
#    export_web_to_tex "#{file_path}.tex"  unless FileTest.exists? "#{file_path}.tex"
#    convert_tex_to_pdf "#{file_path}.tex"
#    send_file "#{file_path}.pdf"
#  end

#  def export_tex
#    file_name = "#{@web.address}-tex-#{@web.revised_at.strftime('%Y-%m-%d-%H-%M-%S')}.tex"
#    file_path = File.join(@wiki.storage_path, file_name)
#    export_web_to_tex(file_path) unless FileTest.exists?(file_path)
#    send_file file_path
#  end

  def feeds
    @rss_with_content_allowed = rss_with_content_allowed?
    # show the template
  end

  def list
    parse_category
    @page_names_that_are_wanted = @pages_in_category.wanted_pages
    @pages_that_are_orphaned = @pages_in_category.orphaned_pages
  end
  
  def recently_revised
    parse_category
    @pages_by_revision = @pages_in_category.by_revision
    @pages_by_day = Hash.new { |h, day| h[day] = [] }
    @pages_by_revision.each do |page| 
      day = Date.new(page.revised_at.year, page.revised_at.month, page.revised_at.day)
      @pages_by_day[day] << page
    end
  end

  def atom_with_content
    if rss_with_content_allowed? 
      render_atom(hide_description = false)
    else
      render :text => 'Atom feed with content for this web is blocked for security reasons. ' +
        'The web is password-protected and not published', :status => 403, :layout => 'error'
    end
  end

  def atom_with_headlines
    render_atom(hide_description = true)
  end

  def search
    @query = params['query']
    render(:text => "Your query string was not valid utf-8", :layout => 'error', :status => 400) and return unless @query.is_utf8?
    @title_results = @web.select { |page| page.name =~ /#{@query}/i }.sort
    @results = @web.select { |page| page.content =~ /#{@query}/i }.sort
    all_pages_found = (@results + @title_results).uniq
    if all_pages_found.size == 1
      redirect_to_page(all_pages_found.first.name)
    end
  end

  # Within a single page --------------------------------------------------------
  
  def cancel_edit
    @page.unlock
    redirect_to_page(@page_name)
  end

  def edit
    if @page.nil? or not @page_name.is_utf8?
      redirect_home
    elsif @page.locked?(Time.now) and not params['break_lock']
      redirect_to :web => @web_name, :action => 'locked', :id => @page_name
    else
      @page.lock(Time.now, @author)
    end
  end
  
  def locked
    render(:text => 'Page name is not valid utf-8.', :status => 400, :layout => 'error') unless @page_name.is_utf8? 
    # to template
  end
  
  def new
    render(:text => 'Page name is not valid utf-8.', :status => 400, :layout => 'error') unless @page_name.is_utf8? 
    # to template
  end

#  def pdf
#    page = wiki.read_page(@web_name, @page_name)
#    safe_page_name = @page.name.gsub(/\W/, '')
#    file_name = "#{safe_page_name}-#{@web.address}-#{@page.revised_at.strftime('%Y-%m-%d-%H-%M-%S')}"
#    file_path = File.join(@wiki.storage_path, file_name)
#
#    export_page_to_tex("#{file_path}.tex") unless FileTest.exists?("#{file_path}.tex")
#    # NB: this is _very_ slow
#    convert_tex_to_pdf("#{file_path}.tex")
#    send_file "#{file_path}.pdf"
#  end

  def print
    if @page.nil?
      redirect_home
    end
    @link_mode ||= :show
    @renderer = PageRenderer.new(@page.revisions.last)
    # to template
  end

  def published
    if not @web.published?
      render(:text => "Published version of web '#{@web_name}' is not available", :status => 404, :layout => 'error')
      return 
    end

    @page_name ||= 'HomePage'
    @page ||= wiki.read_page(@web_name, @page_name)
    @link_mode ||= :publish
    if @page
       @renderer = PageRenderer.new(@page.revisions.last)
    else
      real_page = WikiReference.page_that_redirects_for(@web, @page_name)
        if real_page
          flash[:info] = "Redirected from \"#{@page_name}\"."
          redirect_to :web => @web_name, :action => 'published', :id => real_page, :status => 301
        else
          render(:text => "Page '#{@page_name}' not found", :status => 404, :layout => 'error')
        end
     end
  end
  
  def revision
    get_page_and_revision
    @show_diff = (params[:mode] == 'diff')
    @renderer = PageRenderer.new(@revision)
  end

  def rollback
    get_page_and_revision
  end

  def save
    render(:status => 404, :text => 'Undefined page name', :layout => 'error') and return if @page_name.nil? or not @page_name.is_utf8?
    unless (request.post? || ENV["RAILS_ENV"] == "test")
      headers['Allow'] = 'POST'
      render(:status => 405, :text => 'You must use an HTTP POST', :layout => 'error')
      return
    end
    author_name = params['author']
    author_name = 'AnonymousCoward' if author_name =~ /^\s*$/
    
    begin
      raise Instiki::ValidationError.new('Your name was not valid utf-8') unless author_name.is_utf8?
      raise Instiki::ValidationError.new('Your name cannot contain a "."') if author_name.include? '.'
      cookies['author'] = { :value => author_name, :expires => Time.utc(2030) }
      the_content = params['content']
      filter_spam(the_content)
      unless the_content.is_utf8?
        if @page
          the_content = @page.content
        else
          the_content = ''
        end 
        raise Instiki::ValidationError.new('Your content was not valid utf-8.')
      end
      if @page
        new_name = params['new_name'] || @page_name
        raise Instiki::ValidationError.new('Your new title was not valid utf-8.') unless new_name.is_utf8?
        raise Instiki::ValidationError.new('Your new title cannot contain a "."') if new_name.include? '.'
        raise Instiki::ValidationError.new('A page named "' + new_name.escapeHTML + '" already exists.') if @page_name != new_name && @web.has_page?(new_name)
        wiki.revise_page(@web_name, @page_name, new_name, the_content, Time.now, 
            Author.new(author_name, remote_ip), PageRenderer.new)
        @page.unlock
        @page_name = new_name
      else
        wiki.write_page(@web_name, @page_name, the_content, Time.now, 
            Author.new(author_name, remote_ip), PageRenderer.new)
      end
      redirect_to_page @page_name
    rescue Instiki::ValidationError => e
      flash[:error] = e.to_s
      logger.error e
      if @page
        @page.unlock
        redirect_to :action => 'edit', :web => @web_name, :id => @page_name, :content => the_content
      else
        redirect_to :action => 'new', :web => @web_name, :id => @page_name, :content => the_content
      end
    end
  end

  def show
    if @page
      begin
        @renderer = PageRenderer.new(@page.revisions.last)
        @show_diff = (params[:mode] == 'diff')
        render :action => 'page'
      # TODO this rescue should differentiate between errors due to rendering and errors in 
      # the application itself (for application errors, it's better not to rescue the error at all)
      rescue => e
        logger.error e
        flash[:error] = e.to_s
        if in_a_web?
          redirect_to :action => 'edit', :web => @web_name, :id => @page_name
        else
          raise e
        end
      end
    else
      if not @page_name.nil? and @page_name.is_utf8? and not @page_name.empty?
        real_page = WikiReference.page_that_redirects_for(@web, @page_name)
        if real_page
          flash[:info] = "Redirected from \"#{@page_name}\"."
          redirect_to :web => @web_name, :action => 'show', :id => real_page, :status => 301
        else
          flash[:info] = "Page \"#{@page_name}\" does not exist.\n" +
                         "Please create it now, or hit the \"back\" button in your browser."
          redirect_to :web => @web_name, :action => 'new', :id => @page_name
        end
      else
        render :text => 'Page name is not specified', :status => 404, :layout => 'error'
      end
    end
  end

  def history
    if @page
      @revisions_by_day = Hash.new { |h, day| h[day] = [] }
      @revision_numbers = Hash.new { |h, id| h[id] = [] }
      revision_number = @page.revisions.length
      @page.revisions.reverse.each do |rev|
        day = Date.new(rev.revised_at.year, rev.revised_at.month, rev.revised_at.day)
        @revisions_by_day[day] << rev
        @revision_numbers[rev.id] = revision_number
        revision_number = revision_number - 1
      end
      render :action => 'history'
    else
      if not @page_name.nil? and @page_name.is_utf8? and not @page_name.empty?
        redirect_to :web => @web_name, :action => 'new', :id => @page_name
      else
        render :text => 'Page name is not specified', :status => 404, :layout => 'error'
      end
    end
  end

  def tex
    if @web.markup == :markdownMML or @web.markup == :markdownPNG or @web.markup == :markdown
      @tex_content = Maruku.new(@page.content).to_latex
    else
      @tex_content = 'TeX export only supported with the Markdown text filters.'
    end
  end

  def s5
    if @web.markup == :markdownMML || @web.markup == :markdownPNG || @web.markup == :markdown
      my_rendered = PageRenderer.new(@page.revisions.last)
      @s5_content = my_rendered.display_s5
      @s5_theme = my_rendered.s5_theme
    else
      @s5_content = "S5 not supported with this text filter"
      @s5_theme = "default"
    end
  end

  def html_ext
    if xhtml_enabled? && request.env.include?('HTTP_ACCEPT') &&
           Mime::Type.parse(request.env["HTTP_ACCEPT"]).include?(Mime::XHTML)
       'xhtml'
    else
      'html'
    end       
  end

  protected

  def do_caching?
    flash.empty?
  end
  
  def load_page
    @page_name = params['id']
    @page = @wiki.read_page(@web_name, @page_name) if @page_name
  end

  private

#  def convert_tex_to_pdf(tex_path)
#    # TODO remove earlier PDF files with the same prefix
#    # TODO handle gracefully situation where pdflatex is not available
#    begin
#      wd = Dir.getwd
#      Dir.chdir(File.dirname(tex_path))
#      logger.info `pdflatex --interaction=nonstopmode #{File.basename(tex_path)}`
#    ensure
#      Dir.chdir(wd)
#    end
#  end

  def export_page_to_tex(file_path)
    if @web.markup == :markdownMML || @web.markup == :markdownPNG
      @tex_content = Maruku.new(@page.content).to_latex
    else
      @tex_content = 'TeX export only supported with the Markdown text filters.'
    end
    File.open(file_path, 'w') { |f| f.write(render_to_string(:template => 'wiki/tex', :layout => 'tex')) }
  end

  def export_pages_as_zip(file_type, &block)
    
    file_prefix = "#{@web.address}-#{file_type}-"
    timestamp = @web.revised_at.strftime('%Y-%m-%d-%H-%M-%S')
    file_path = File.join(@wiki.storage_path, file_prefix + timestamp + '.zip')
    tmp_path = "#{file_path}.tmp"

    Zip::ZipOutputStream.open(tmp_path) do |zip_out|
      @web.select.by_name.each do |page|
        zip_out.put_next_entry("#{CGI.escape(page.name)}.#{file_type}")
        zip_out.puts(block.call(page))
      end
      # add an index file, if exporting to HTML
      if file_type.to_s.downcase == html_ext
        zip_out.put_next_entry "index.#{html_ext}"
        zip_out.puts "<html xmlns='http://www.w3.org/1999/xhtml'><head>" +
            "<META HTTP-EQUIV=\"Refresh\" CONTENT=\"0;URL=HomePage.#{file_type}\"></head></html>"
      end
    end
    FileUtils.rm_rf(Dir[File.join(@wiki.storage_path, file_prefix + '*.zip')])
    FileUtils.mv(tmp_path, file_path)
    send_file file_path
  end

#  def export_web_to_tex(file_path)
#    if @web.markup == :markdownMML
#      @tex_content = Maruku.new(@page.content).to_latex
#    else
#      @tex_content = 'TeX export only supported with the Markdown text filters.'
#    end
#    @tex_content = table_of_contents(@web.page('HomePage').content, render_tex_web)
#    File.open(file_path, 'w') { |f| f.write(render_to_string(:template => 'wiki/tex_web', :layout => tex)) }
#  end

  def get_page_and_revision
    if params['rev']
      @revision_number = params['rev'].to_i
    else
      @revision_number = @page.revisions.length
    end
    @revision = @page.revisions[@revision_number - 1]
  end

  def parse_category
    @categories = WikiReference.list_categories(@web).sort
    @category = params['category']
    if @category
      @set_name = "category '#{@category}'"
      pages = WikiReference.pages_in_category(@web, @category).sort.map { |page_name| @web.page(page_name) }
      @pages_in_category = PageSet.new(@web, pages)
    else
      # no category specified, return all pages of the web
      @pages_in_category = @web.select_all.by_name
      @set_name = 'the web'
    end
  end
  
  def remote_ip
    ip = request.remote_ip
    logger.info(ip)
    ip.dup.gsub!(Regexp.union(Resolv::IPv4::Regex, Resolv::IPv6::Regex), '\0') || 'bogus address'
  end

  def render_atom(hide_description = false, limit = 15)
    @pages_by_revision = @web.select.by_revision.first(limit)
    @hide_description = hide_description
    @link_action = @web.password ? 'published' : 'show'
    render :action => 'atom'
  end 

  def render_tex_web
    @web.select.by_name.inject({}) do |tex_web, page|
      if  @web.markup == :markdownMML || @web.markup == :markdownPNG
        tex_web[page.name] = Maruku.new(page.content).to_latex
      else
        tex_web[page.name] = 'TeX export only supported with the Markdown text filters.'
      end
      tex_web
    end
  end

  def rss_with_content_allowed?
    @web.password.nil? or @web.published?
  end
  
  def truncate(text, length = 30, truncate_string = '...')
    if text.length > length then text[0..(length - 3)] + truncate_string else text end
  end
  
  def filter_spam(content)
    @@spam_patterns ||= load_spam_patterns
    @@spam_patterns.each do |pattern| 
      raise Instiki::ValidationError.new("Your edit was blocked by spam filtering") if content =~ pattern
    end
  end

  def load_spam_patterns
    spam_patterns_file = "#{RAILS_ROOT}/config/spam_patterns.txt"
    if File.exists?(spam_patterns_file)
      File.readlines(spam_patterns_file).inject([]) { |patterns, line| patterns << Regexp.new(line.chomp, Regexp::IGNORECASE) } 
    else
      []
    end
  end

end
