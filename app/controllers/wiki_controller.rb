require 'fileutils'
require 'redcloth_for_tex'
require 'parsedate'
require 'zip/zip'

class WikiController < ApplicationController

  caches_action :show, :published, :authors, :recently_revised, :list
  cache_sweeper :revision_sweeper

  layout 'default', :except => [:rss_feed, :rss_with_content, :rss_with_headlines, :tex,  :export_tex, :export_html]

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
    if password_check(@params['password'])
      redirect_home
    else 
      flash[:info] = password_error(@params['password'])
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
  
  def export_html
    stylesheet = File.read(File.join(RAILS_ROOT, 'public', 'stylesheets', 'instiki.css'))
    export_pages_as_zip('html') do |page| 

      renderer = PageRenderer.new(page.revisions.last)
      rendered_page = <<-EOL
        <!DOCTYPE html
        PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
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

  def export_pdf
    file_name = "#{@web.address}-tex-#{@web.revised_at.strftime('%Y-%m-%d-%H-%M-%S')}"
    file_path = File.join(@wiki.storage_path, file_name)

    export_web_to_tex "#{file_path}.tex"  unless FileTest.exists? "#{file_path}.tex"
    convert_tex_to_pdf "#{file_path}.tex"
    send_file "#{file_path}.pdf"
  end

  def export_tex
    file_name = "#{@web.address}-tex-#{@web.revised_at.strftime('%Y-%m-%d-%H-%M-%S')}.tex"
    file_path = File.join(@wiki.storage_path, file_name)
    export_web_to_tex(file_path) unless FileTest.exists?(file_path)
    send_file file_path
  end

  def feeds
    @rss_with_content_allowed = rss_with_content_allowed?
    # show the template
  end

  def list
    parse_category
    @pages_by_name = @pages_in_category.by_name
    @page_names_that_are_wanted = @pages_in_category.wanted_pages
    @pages_that_are_orphaned = @pages_in_category.orphaned_pages
  end
  
  def recently_revised
    parse_category
    @pages_by_revision = @pages_in_category.by_revision
  end

  def rss_with_content
    if rss_with_content_allowed?
      render_rss(hide_description = false, *parse_rss_params)
    else
      render_text 'RSS feed with content for this web is blocked for security reasons. ' +
        'The web is password-protected and not published', '403 Forbidden'
    end
  end

  def rss_with_headlines
    render_rss(hide_description = true, *parse_rss_params)
  end

  def search
    @query = @params['query']
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
    if @page.nil?
      redirect_home
    elsif @page.locked?(Time.now) and not @params['break_lock']
      redirect_to :web => @web_name, :action => 'locked', :id => @page_name
    else
      @page.lock(Time.now, @author)
    end
  end
  
  def locked
    # to template
  end
  
  def new
    # to template
  end

  def pdf
    page = wiki.read_page(@web_name, @page_name)
    safe_page_name = @page.name.gsub(/\W/, '')
    file_name = "#{safe_page_name}-#{@web.address}-#{@page.revised_at.strftime('%Y-%m-%d-%H-%M-%S')}"
    file_path = File.join(@wiki.storage_path, file_name)

    export_page_to_tex("#{file_path}.tex") unless FileTest.exists?("#{file_path}.tex")
    # NB: this is _very_ slow
    convert_tex_to_pdf("#{file_path}.tex")
    send_file "#{file_path}.pdf"
  end

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
      render(:text => "Published version of web '#{@web_name}' is not available", :status => 404)
      return 
    end

    page_name = @page_name || 'HomePage'
    page = wiki.read_page(@web_name, page_name)
    render(:text => "Page '#{page_name}' not found", status => 404) and return unless page
    
    @renderer = PageRenderer.new(page.revisions.last)
  end
  
  def revision
    get_page_and_revision
    @renderer = PageRenderer.new(@revision)
  end

  def rollback
    get_page_and_revision
  end

  def save
    redirect_home if @page_name.nil?
    cookies['author'] = { :value => @params['author'], :expires => Time.utc(2030) }

    begin
      if @page
        wiki.revise_page(@web_name, @page_name, @params['content'], Time.now, 
            Author.new(@params['author'], remote_ip), PageRenderer.new)
        @page.unlock
      else
        wiki.write_page(@web_name, @page_name, @params['content'], Time.now, 
            Author.new(@params['author'], remote_ip), PageRenderer.new)
      end
      redirect_to_page @page_name
    rescue => e
      flash[:error] = e
      logger.error e
      flash[:content] = @params['content']
      if @page
        @page.unlock
        redirect_to :action => 'edit', :web => @web_name, :id => @page_name
      else
        redirect_to :action => 'new', :web => @web_name, :id => @page_name
      end
    end
  end

  def show
    if @page
      begin
        @renderer = PageRenderer.new(@page.revisions.last)
        render_action 'page'
      # TODO this rescue should differentiate between errors due to rendering and errors in 
      # the application itself (for application errors, it's better not to rescue the error at all)
      rescue => e
        logger.error e
        flash[:error] = e.message
        if in_a_web?
          redirect_to :action => 'edit', :web => @web_name, :id => @page_name
        else
          raise e
        end
      end
    else
      if not @page_name.nil? and not @page_name.empty?
        redirect_to :web => @web_name, :action => 'new', :id => @page_name
      else
        render_text 'Page name is not specified', '404 Not Found'
      end
    end
  end

  def tex
    @tex_content = RedClothForTex.new(@page.content).to_tex
  end


  private
    
  def convert_tex_to_pdf(tex_path)
    # TODO remove earlier PDF files with the same prefix
    # TODO handle gracefully situation where pdflatex is not available
    begin
      wd = Dir.getwd
      Dir.chdir(File.dirname(tex_path))
      logger.info `pdflatex --interaction=nonstopmode #{File.basename(tex_path)}`
    ensure
      Dir.chdir(wd)
    end
  end

  def export_page_to_tex(file_path)
    tex
    File.open(file_path, 'w') { |f| f.write(render_to_string(:template => 'wiki/tex', :layout => nil)) }
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
      if file_type.to_s.downcase == 'html'
        zip_out.put_next_entry 'index.html'
        zip_out.puts "<html><head>" +
            "<META HTTP-EQUIV=\"Refresh\" CONTENT=\"0;URL=HomePage.#{file_type}\"></head></html>"
      end
    end
    FileUtils.rm_rf(Dir[File.join(@wiki.storage_path, file_prefix + '*.zip')])
    FileUtils.mv(tmp_path, file_path)
    send_file file_path
  end

  def export_web_to_tex(file_path)
    @tex_content = table_of_contents(@web.page('HomePage').content, render_tex_web)
    File.open(file_path, 'w') { |f| f.write(render_to_string(:template => 'wiki/tex_web', :layout => nil)) }
  end

  def get_page_and_revision
    @revision_number = @params['rev'].to_i
    @revision = @page.revisions[@revision_number]
  end

  def parse_category
    @category = @params['category']
    @categories = WikiReference.list_categories.sort
    page_names_in_category = WikiReference.pages_in_category(@category)
    if (page_names_in_category.empty?)
      @pages_in_category = @web.select_all.by_name
      @set_name = 'the web'
    else 
      @pages_in_category = @web.select { |page| page_names_in_category.include?(page.name) }.by_name
      @set_name = "category '#{@category}'"
    end
  end

  def parse_rss_params
    if @params.include? 'limit'
      limit = @params['limit'].to_i rescue nil
      limit = nil if limit == 0
    else
      limit = 15
    end
    start_date = Time.local(*ParseDate::parsedate(@params['start'])) rescue nil
    end_date = Time.local(*ParseDate::parsedate(@params['end'])) rescue nil
    [ limit, start_date, end_date ]
  end
  
  def remote_ip
    ip = @request.remote_ip
    logger.info(ip)
    ip
  end

  def render_rss(hide_description = false, limit = 15, start_date = nil, end_date = nil)
    if limit && !start_date && !end_date
      @pages_by_revision = @web.select.by_revision.first(limit)
    else
      @pages_by_revision = @web.select.by_revision
      @pages_by_revision.reject! { |page| page.revised_at < start_date } if start_date
      @pages_by_revision.reject! { |page| page.revised_at > end_date } if end_date
    end
    
    @hide_description = hide_description
    @link_action = @web.password ? 'published' : 'show'
    
    render :action => 'rss_feed'
  end

  def render_tex_web
    @web.select.by_name.inject({}) do |tex_web, page|
      tex_web[page.name] = RedClothForTex.new(page.content).to_tex
      tex_web
    end
  end

  def rss_with_content_allowed?
    @web.password.nil? or @web.published?
  end
  
  def truncate(text, length = 30, truncate_string = '...')
    if text.length > length then text[0..(length - 3)] + truncate_string else text end
  end
  
end
