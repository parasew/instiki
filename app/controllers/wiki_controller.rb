require 'fileutils'
require 'maruku'
require 'maruku/ext/math'
require 'zip/zip'
require 'itex_stringsupport'
require 'resolv'
require 'digest'
require 'strscan'

class WikiController < ApplicationController

  before_filter :load_page
  before_filter :dnsbl_check, :only => [:edit, :new, :save, :export_html, :export_markup]
  caches_action :show, :published, :authors, :tex, :s5, :print, :recently_revised, :list, :file_list, :source,
        :history, :revision, :atom_with_content, :atom_with_headlines, :atom_with_changes, :if => Proc.new { |c| c.send(:do_caching?) }
  cache_sweeper :revision_sweeper

  layout 'default', :except => [:atom_with_content, :atom_with_headlines, :atom_with_changes, :atom, :source, :tex, :s5, :export_html]

  def index
    if @web_name
      redirect_home
    elsif not @wiki.setup?
      redirect_to :controller => 'admin', :action => 'create_system'
    elsif @wiki.webs.size == 1
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
    export_pages_as_zip(html_ext) do |page| 
      renderer = PageRenderer.new(page.current_revision)
      rendered_page = <<-EOL
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <title>#{page.plain_name} in #{@web.name}</title>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1"/>

  <script src="public/javascripts/page_helper.js" type="text/javascript"></script>
  <link href="public/stylesheets/instiki.css" media="all" rel="stylesheet" type="text/css" />
  <link href="public/stylesheets/syntax.css" media="all" rel="stylesheet" type="text/css" />
  <style type="text/css">
    h1#pageName, div.info, .newWikiWord a, a.existingWikiWord, .newWikiWord a:hover, [actiontype="toggle"]:hover, #TextileHelp h3 {
      color: ##{@web ? @web.color : "393"};
    }
    a:visited.existingWikiWord {
      color: ##{darken(@web ? @web.color : "393")};
    }
  </style>

  <style type="text/css"><!--/*--><![CDATA[/*><!--*/    
    #{@web ? @web.additional_style : ''}
  /*]]>*/--></style>
  <script src="public/javascripts/prototype.js" type="text/javascript"></script>
  <script src="public/javascripts/effects.js" type="text/javascript"></script>
  <script src="public/javascripts/dragdrop.js" type="text/javascript"></script>
  <script src="public/javascripts/controls.js" type="text/javascript"></script>
  <script src="public/javascripts/application.js" type="text/javascript"></script>

  <script type="text/x-mathjax-config">
  <!--//--><![CDATA[//><!--
    MathJax.Ajax.config.path["Contrib"] = "public/MathJax";
    MathJax.Hub.Config({
      MathML: { useMathMLspacing: true },
      "HTML-CSS": { scale: 90,
                    noReflows: false,
                    extensions: ["handle-floats.js"]
       }
    });
    MathJax.Hub.Queue( function () {
       var fos = document.getElementsByTagName('foreignObject');
       for (var i = 0; i < fos.length; i++) {
         MathJax.Hub.Typeset(fos[i]);
       }
    });
  //--><!]]>
  </script>

    <script type="text/javascript">
      <!--//--><![CDATA[//><!--
      window.addEventListener("DOMContentLoaded", function () {
        var div = document.createElement('div');
        var math = document.createElementNS('http://www.w3.org/1998/Math/MathML', 'math');
        document.body.appendChild(div);
        div.appendChild(math);
      // Test for MathML support comparable to WebKit version https://trac.webkit.org/changeset/203640 or higher.
        div.setAttribute('style', 'font-style: italic');
        var mathml_unsupported = !(window.getComputedStyle(div.firstChild).getPropertyValue('font-style') === 'normal');
        div.parentNode.removeChild(div);
        if (mathml_unsupported) {
          // MathML does not seem to be supported...
          var s = document.createElement('script');
          s.src = "public/MathJax/MathJax.js?config=MML_HTMLorMML";
          document.querySelector('head').appendChild(s);
        } else {
          document.head.insertAdjacentHTML("beforeend", '<style>svg[viewBox] {max-width: 100%}</style>');
        }
      });
      //--><!]]>
    </script>

</head>
<body xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:se="http://svg-edit.googlecode.com">
 <div id="Container">
  <div id="Content">
  <h1 id="pageName">
  #{xhtml_enabled? ? %{<span id="svg_logo"><svg version="1.1" width="100%" height="100%" viewBox='0 -1 180 198' xmlns='http://www.w3.org/2000/svg'>
      <path id="svg_logo_path" fill="##{@web ? @web.color : "393"}" stroke-width='0.5' stroke='#000' d='
        M170,60c4,11-1,20-12,25c-9,4-25,3-20,15c5,5,15,0,24,1c11,1,21,11,14,21c-10,15-35,6-48-1c-5-3-27-23-32-10c-1,13,15,10,22,16
        c11,4,24,14,34,20c12,10,7,25-9,23c-11-1-22-9-30-16c-5-5-13-18-21-9c-2,6,2,11,5,14c9,9,22,14,22,31c-2,8-12,8-18,4c-4-3-9-8-11-13
        c-3-6-5-18-12-18c-14-1-5,28-18,30c-9,2-13-9-12-16c1-14,12-24,21-31c5-4,17-13,10-20c-9-10-19,12-23,16c-7,7-17,16-31,15
        c-9-1-18-9-11-17c5-7,14-4,23-6c6-1,15-8,8-15c-5-6-57,2-42-24c7-12,51,4,61,6c6,1,17,4,18-4c2-11-12-7-21-8c-21-2-49-14-49-34
        c0-5,3-11,8-11C31,42,34,65,42,67c6,1,9-3,8-9C49,49,38,40,40,25c1-5,4-15,13-14c10,2,11,18,13,29c1,8,0,24,7,28c15,0,5-22,4-30
        C74,23,78,7,87,1c8-4,14,1,16,9c2,11-8,21-2,30c8,2,11-6,14-12c9-14,36-18,30,5c-3,9-12,19-21,24c-6,4-22,10-23,19c-2,14,15,2,18-2
        c9-9,20-18,33-22C159,52,166,54,170,60' />
    </svg></span>} : ''}
  <span class="webName">#{@web.name}</span><br />
  #{page.plain_name}    
  </h1>
#{renderer.display_content_for_export}
  <div class="byline">
  #{page.revisions? ? "Revised" : "Created" } on #{ page.revised_at.strftime('%B %d, %Y %H:%M:%S') }
  by
  #{ UrlGenerator.new(self).make_link(@web, page.author.name, nil, @web, nil, { :mode => :export }) }
  </div>
  </div>
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
    @pages_by_revision = @pages_in_category.by_revision.first(50)
    @pages_by_day = Hash.new { |h, day| h[day] = [] }
    @pages_by_revision.each do |page| 
      day = Date.new(page.revised_at.year, page.revised_at.month, page.revised_at.day)
      @pages_by_day[day] << page
    end
  end

  def atom_with_content
    if rss_with_content_allowed?
      p = params['limit'].to_i
      (p != 0) ? render_atom(hide_description = false, p) : render_atom(hide_description = false)
    else
      render :text => 'Atom feed with content for this web is blocked for security reasons. ' +
        'The web is password-protected and not published', :status => 403, :layout => 'error'
    end
  end

  def atom_with_headlines
    p = params['limit'].to_i
    (p != 0) ? render_atom(hide_description = true, p) : render_atom(hide_description = true)
  end

  def atom_with_changes(limit = 15)
    if rss_with_content_allowed?
      render_atom_changes(hide_description = false, limit)
    else
      render :text => 'Atom feed with content for this web is blocked for security reasons. ' +
        'The web is password-protected and not published', :status => 403, :layout => 'error'
    end
  end

  def tex_list
    return unless is_post
    if [:markdownMML, :markdownPNG, :markdown].include?(@web.markup)
      @tex_content = ''
      tikz_libs = []
      # Ruby 1.9.x has ordered hashes; 1.8.x doesn't. So let's just parse the query ourselves.
      # In Ruby 1.9 and later, ActiveSupport::OrderedHash is just a Hash.
      ordered_params = ActiveSupport::OrderedHash[*request.raw_post.split('&').collect {|k_v| k_v.split('=').collect {|x| CGI::unescape(x)}}.flatten]
      ordered_params.each do |name, p|
        if p == 'tex' && @web.has_page?(name)
          @tex_content << "\\section*\{#{Maruku.new(name).to_latex.strip}\}\n\n"
          s = convert_to_tex(@web.page(name).content)
          @tex_content << s[0]
          tikz_libs.concat s[1]
        end
      end
      @tikz_libraries = tikz_libs.uniq
    else
      @tex_content = 'TeX export only supported with the Markdown text filters.'
    end
    if @tex_content == ''
      flash[:error] = "You didn't select any pages to export."
      redirect_to :back
      return
    end
    expire_action :controller => 'wiki', :web => @web.address, :action => 'list', :category => params['category']
    render(:layout => 'tex')
  end

  def search
    @query = params['query'] ? params['query'].purify : ''
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
    elsif @page.locked?(Time.now) and not params['break_lock']
      redirect_to :web => @web_name, :action => 'locked', :id => @page_name
    else
      @page.lock(Time.now, @author)
    end
  end

  def locked
    # to template
  end

  def new
    redirect_to :web => @web_name, :action => 'edit', :id => @page_name unless @page.nil?
    # to template
  end

  def print
    if @page.nil?
      redirect_home
    else
      @link_mode ||= :show
      @renderer = PageRenderer.new(@page.current_revision)
      # to template
    end
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
       @renderer = PageRenderer.new(@page.current_revision)
    else
      real_pages = WikiReference.pages_that_redirect_for(@web, @page_name)
      real_page = real_pages.last
      if real_page
        if real_pages.length == 1
          flash[:info] = "Redirected from \"#{@page_name}\"."
        else
          list_pages = real_pages.collect do |r| 
            "<a href=\"#{url_for(:web => @web.address, :action => 'published', :id => r, :only_path => true)}\">#{r.escapeHTML}</a>"
          end
          c = list_pages.length > 2 ? 'all' : 'both'
          flash[:error] = "Redirected from \"#{@page_name}\".\nNote: #{list_pages.to_sentence} #{c} redirect for \"#{@page_name}\".".html_safe
        end
          redirect_to :web => @web_name, :action => 'published', :id => real_page, :status => 301
      else
        render(:text => "Page '#{@page_name}' not found", :status => 404, :layout => 'error')
      end
     end
  end

  def revision
    if @page.nil?
      redirect_home
    else
      get_page_and_revision
      @show_diff = (params[:mode] == 'diff')
      @renderer = PageRenderer.new(@revision)
    end
  end

  def rollback
    get_page_and_revision
    if @page.locked?(Time.now) and not params['break_lock']
      redirect_to :web => @web_name, :action => 'locked', :id => @page_name
    else
      @page.lock(Time.now, @author)
    end
  end

  def save
    render(:status => 404, :text => 'Undefined page name', :layout => 'error') and return if @page_name.nil?
    return unless is_post
    author_name = params['author'].strip.purify
    author_name = 'AnonymousCoward' if author_name =~ /^\s*$/

    begin
      the_content = params['content'].purify
      prev_content = ''
      filter_spam(the_content)
      cookies['author'] = { :value => author_name.dup.as_bytes, :expires => Time.utc(2030) }
      if @page
        new_name = params['new_name'] ? params['new_name'].purify.strip : @page_name
        new_name = @page_name if new_name.empty?
        prev_content = @page.current_revision.content
        raise Instiki::ValidationError.new('A page named "' + new_name.escapeHTML + '" already exists.') if
            @page_name != new_name && @web.has_page?(new_name)
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
      param_hash = {:web => @web_name, :id => @page_name}
      # Work around Rails bug: flash will not display if query string is longer than 10192 bytes
      param_hash.update( :content => the_content ) if the_content && 
         CGI::escape(the_content).length < 10183 && the_content != prev_content
      if @page
        @page.unlock
        redirect_to param_hash.update( :action => 'edit' )
      else
        redirect_to param_hash.update( :action => 'new' )
      end
    end
  end

  def show
    if @page
      begin
        @renderer = PageRenderer.new(@page.current_revision)
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
      if not @page_name.nil? and not @page_name.empty?
        real_pages = WikiReference.pages_that_redirect_for(@web, @page_name)
        real_page = real_pages.last
        if real_page
          if real_pages.length == 1
            flash[:info] = "Redirected from \"#{@page_name}\"."
          else
            list_pages = real_pages.collect do |r|
              "<a href=\"#{url_for(:web => @web.address, :action => 'show', :id => r, :only_path => true)}\">#{r.escapeHTML}</a>"
            end
            c = list_pages.length > 2 ? 'all' : 'both'
            flash[:error] = "Redirected from \"#{@page_name}\".\nNote: #{list_pages.to_sentence} #{c} redirect for \"#{@page_name}\".".html_safe
          end
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
      revision_number = @page.rev_ids.size
      @page.rev_ids.reverse.each do |rev|
        day = Date.new(rev.revised_at.year, rev.revised_at.month, rev.revised_at.day)
        @revisions_by_day[day] << rev
        @revision_numbers[rev.id] = revision_number
        revision_number = revision_number - 1
      end
      render :action => 'history'
    else
      if not @page_name.nil? and not @page_name.empty?
        redirect_to :web => @web_name, :action => 'new', :id => @page_name
      else
        render :text => 'Page name is not specified', :status => 404, :layout => 'error'
      end
    end
  end

  def source
    if @page.nil?
      redirect_home
    else
      @revision = @page.revisions[params['rev'].to_i - 1] if params['rev']
    end
  end

  def tex
    @tikz_libraries = []
    if [:markdownMML, :markdownPNG, :markdown].include?(@web.markup)
      s = convert_to_tex(@page.content)
      @tex_content = s[0]
      @tikz_libraries = s[1]
    else
      @tex_content = 'TeX export only supported with the Markdown text filters.'
      @tikz_libraries = []
    end
    render(:layout => 'tex')
  end

  def s5
    if [:markdownMML, :markdownPNG, :markdown].include?(@web.markup)
      my_rendered = PageRenderer.new(@page.current_revision)
      @s5_content = my_rendered.display_s5
      @s5_theme = my_rendered.s5_theme
    else
      @s5_content = "S5 not supported with this text filter"
      @s5_theme = "default"
    end
  end

  def image_path(s)
    @template.image_path(s)
  end

  protected

  def do_caching?
    flash.empty?
  end

  def load_page
    @page_name = params['id'] ? params['id'].purify : nil
    @page = @wiki.read_page(@web_name, @page_name) if @page_name
  end

  private

  def export_page_to_tex(file_path)
    if @web.markup == :markdownMML || @web.markup == :markdownPNG
      s = convert_to_tex(@page.content)
      @tex_content = s[0]
      @tikz_libraries = s[1]
    else
      @tex_content = 'TeX export only supported with the Markdown text filters.'
      @tikz_libraries = []
    end
    File.open(file_path, 'w') { |f| f.write(render_to_string(:template => 'wiki/tex', :layout => 'tex')) }
  end

  def export_pages_as_zip(file_type, &block)
    file_prefix = "#{@web.address}-#{file_type}-"
    timestamp = @web.revised_at.strftime('%Y-%m-%d-%H-%M-%S')
    file_path = @wiki.storage_path.join(file_prefix + timestamp + '.zip')
    tmp_path = "#{file_path}.tmp"

    Zip::ZipFile.open(tmp_path, Zip::ZipFile::CREATE) do |zip_out|
      @web.select.by_name.each do |page|
        zip_out.get_output_stream("#{CGI.escape(page.name)}.#{file_type}") do |f|
          f.puts(block.call(page))
        end
      end
      # add an index file, and the stylesheet and javascript directories, if exporting to HTML
      if file_type.to_s.downcase == html_ext
        zip_out.get_output_stream("index.#{html_ext}") do |f|
          f.puts "<html xmlns='http://www.w3.org/1999/xhtml'><head>" +
            "<meta http-equiv=\"Refresh\" content=\"0;URL=HomePage.#{html_ext}\" /></head></html>"
        end
        dir = Rails.root.join('public')
        Dir["#{dir}/{images,javascripts,s5,stylesheets}/**/*"].each do |f|
          zip_out.add "public#{f.sub(dir.to_s,'')}", f
        end
      end
      files = @web.files_path
      Dir["#{files}/**/*"].each do |f|
        zip_out.add "files#{f.sub(files.to_s,'')}", f
      end
    end
    FileUtils.rm_rf(Dir[@wiki.storage_path.join(file_prefix + '*.zip').to_s])
    FileUtils.mv(tmp_path, file_path)
    send_file file_path
  end

  def get_page_and_revision
    rev = params['rev'].to_i if params['rev']
    prs = @page.rev_ids.size
    if rev && rev > 0 && rev <= prs
      @revision_number = rev
    else
      @revision_number = prs
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

  def render_atom(hide_description = false, limit = 15)
    @pages_by_revision = @web.select.by_revision.first(limit)
    @hide_description = hide_description
    @link_action = @web.password ? 'published' : 'show'
    render :action => 'atom'
  end

  def render_atom_changes(hide_description = false, limit = 15)
    @revisions = @web.revisions_by_date.last(limit).reverse
    @hide_description = hide_description
    @link_action = @web.password ? 'published' : 'show'
    render :action => 'atom_changes'
  end

  def convert_to_tex(string)
    tikzpictures = Hash.new
    tikz_libs = []
    s = string.gsub(/\\begin\{(tikzpicture|tikzcd)\}.*?\\end\{(tikzpicture|tikzcd)\}/m) do |match|
      i = Digest::SHA2.hexdigest(rand(1000000).to_s)
      text, libs = extract_libraries(match)
      tikzpictures.update(i => text)
      tikz_libs << libs
      i
    end
    s = Maruku.new(s).to_latex
    tikzpictures.each {|key,val| s.sub!(key, val)}
    return [s, tikz_libs.uniq]
  end

  def extract_libraries(s)
    buffer = StringScanner.new(s)
    libraries = []
    out = ''
    while ! buffer.eos?
      if buffer.scan(/(.*?)\\usetikzlibrary\{/m)
        out << buffer[1]
      else
        out << buffer.rest
        return [out, libraries]
      end
      buffer.scan(/(.*?)\}/)
      libraries << buffer[1].split(/\s*,\s*/)
    end
    return [out, libraries]
  end

  def rss_with_content_allowed?
    @web.password.nil? or @web.published?
  end

  def filter_spam(content)
    @@spam_patterns ||= load_spam_patterns
    @@spam_patterns.each do |pattern| 
      raise Instiki::ValidationError.new("Your edit was blocked by spam filtering") if content =~ pattern
    end
  end

  def load_spam_patterns
    spam_patterns_file = Rails.root.join('config', 'spam_patterns.txt')
    if File.exists?(spam_patterns_file)
      spam_patterns_file.readlines.inject([]) { |patterns, line| patterns << Regexp.new(line.chomp, Regexp::IGNORECASE) }
    else
      []
    end
  end

end
