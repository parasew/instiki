require 'instiki_stringsupport'

class AbstractUrlGenerator

  def initialize(controller)
    raise 'Controller cannot be nil' if controller.nil?
    @controller = controller
  end

  # Create a link for the given page (or file) name and link text based
  # on the render mode in options and whether the page (file) exists
  # in the web.
  def make_link(current_web, asked_name, anchor_name, web, text = nil, options = {})
    @web = current_web
    mode = (options[:mode] || :show).to_sym
    link_type = (options[:link_type] || :show).to_sym

    if (link_type == :show)
      page_exists = web.has_page?(asked_name)
      known_page = page_exists || web.has_redirect_for?(asked_name)
      if known_page && !page_exists
        name = web.page_that_redirects_for(asked_name).name
      else
        name = asked_name
      end
    elsif (link_type == :audio || link_type == :video)
       namelist = []
       known_pages = true
       asked_name.split(/\s+/).each do |name|
         return bad_filename(name) unless WikiFile.is_valid?(name)
         known_name =  web.has_file?(name)
         known_pages = false unless known_name
         namelist << [name, known_name]
       end
       description = web.description(asked_name)
       description = description.unescapeHTML.escapeHTML if description
    else
      name = asked_name
      known_page = web.has_file?(name)
      description = web.description(name)
      description = description.unescapeHTML.escapeHTML if description
    end
    if (text == asked_name)
      text = description || text
    else
      text = text || description
    end
    text = (text || WikiWords.separate(asked_name)).unescapeHTML.escapeHTML
    
    case link_type
    when :show
      page_link(mode, name, anchor_name, text, web.address, known_page)
    when :file
      file_link(mode, name, text, web.address, known_page, description)
    when :pic
      pic_link(mode, name, text, web.address, known_page)
    when :audio
      media_link(mode, namelist, text, web.address, known_pages, 'audio')
    when :video
      media_link(mode, namelist, text, web.address, known_pages, 'video')
    when :cdf
      cdf_link(mode, name, text, web.address, known_page)
    when :youtube
      youtube_link(mode, name, text)
    when :delete
      delete_link(mode, name, web.address, known_page)
    else
      raise "Unknown link type: #{link_type}"
    end
  end

  def url_for(hash = {})
    @controller.url_for hash
  end  
end

class UrlGenerator < AbstractUrlGenerator

  private

  def file_link(mode, name, text, web_address, known_file, description)
    return bad_filename(name) unless WikiFile.is_valid?(name) 
    case mode
    when :export
      if known_file
        %{<a class="existingWikiWord" title="#{description}" href="files/#{CGI.escape(name)}">#{text}</a>}
      else 
        %{<span class="newWikiWord">#{text}</span>}
      end
    when :publish
      if known_file 
        href = @controller.url_for :controller => 'file', :web => web_address, :action => 'file',
            :id => name, :only_path => true
        %{<a class="existingWikiWord"  title="#{description}" href="#{href}">#{text}</a>}
      else 
        %{<span class="newWikiWord">#{text}</span>}
      end
    else 
      href = @controller.url_for :controller => 'file', :web => web_address, :action => 'file', 
          :id => name, :only_path => true
      if known_file
        %{<a class="existingWikiWord"  title="#{description}" href="#{href}">#{text}</a>}
      else 
        %{<span class="newWikiWord">#{text}<a href="#{href}">?</a></span>}
      end
    end
  end

  def page_link(mode, name, anchor_name, text, web_address, known_page)
    case mode
    when :export
      if known_page 
        %{<a class="existingWikiWord" href="#{CGI.escape(name)}.#{html_ext}#{'#'+anchor_name if anchor_name}">#{text}</a>}
      else 
        %{<span class="newWikiWord">#{text}</span>} 
      end
    when :publish
      if known_page
        wikilink_for(mode, name, anchor_name, text, web_address)
      else 
        %{<span class="newWikiWord">#{text}</span>} 
      end
    else 
      if known_page
        wikilink_for(mode, name, anchor_name, text, web_address)
      else 
        href = @controller.url_for :controller => 'wiki', :web => web_address, :action => 'new', 
            :id => name, :only_path => true
        %{<span class="newWikiWord">#{text}<a href="#{href}">?</a></span>}
      end
    end
  end

  def pic_link(mode, name, text, web_address, known_pic)
    return bad_filename(name) unless WikiFile.is_valid?(name) 
    href = @controller.url_for :controller => 'file', :web => web_address, :action => 'file',
      :id => name, :only_path => true
    case mode
    when :export
      if known_pic 
        %{<img alt="#{text}" src="files/#{CGI.escape(name)}" />}
      else 
        %{<img alt="#{text}" src="no image" />}
      end
    when :publish
      if known_pic 
        %{<img alt="#{text}" src="#{href}" />}
      else 
        %{<span class="newWikiWord">#{text}</span>} 
      end
    else 
      if known_pic 
        %{<img alt="#{text}" src="#{href}" />}
      else 
        %{<span class="newWikiWord">#{text}<a href="#{href}">?</a></span>} 
      end
    end
  end

  def media_link(mode, namelist, text, web_address, known_media, media_type)
    if ( known_media || mode == :export || mode == :publish )
      link = %{<#{media_type} controls="controls">}
      link_end = %{\n#{text}\n</#{media_type}>}
    else
      link = %{&#x5B;&#x5B;upload #{media_type} files:}
      link_end = %{ #{text}&#x5D;&#x5D;}
    end
    namelist.each do |v|
      name = v[0]
      known = v[1]
      href = @controller.url_for :controller => 'file', :web => web_address, :action => 'file',
        :id => name, :only_path => true
      type = @web.mime_type(name)
      type_attr = type ? %{ type="#{type}"} : ''
      case mode
      when :export
          link << %{\n  <source src="files/#{CGI.escape(name)}"#{type_attr}/>} if known
      when :publish
          link << %{\n  <source src="#{href}"#{type_attr}/>} if known
      else 
        if known 
          link << %{\n  <source src="#{href}"#{type_attr}/>}
        else 
          link << %{ <span class="newWikiWord">#{name}<a href="#{href}">?</a></span>} 
        end
      end
    end
    link << link_end
  end

  def cdf_link(mode, name, text, web_address, known_cdf)
    return bad_filename(name) unless WikiFile.is_valid?(name) 
    href = @controller.url_for :controller => 'file', :web => web_address, :action => 'file',
      :id => name, :only_path => true
    badge_path = @controller.image_path("cdf-player-white.png").split(/\?/)[0]
    re = /\s*(\d{1,4})\s*x\s*(\d{1,4})\s*/
    tt = re.match(text)
    if tt
      width = tt[1]
      height = tt[2]
    else
      width = '500'
      height = '300'
    end
    case mode
    when :export
      if known_cdf
        cdf_div("files/#{CGI.escape(name)}", width, height, badge_path)
      else 
        CGI.escape(name)
      end
    when :publish
      if known_cdf
        cdf_div(href, width, height, badge_path)
      else 
        %{<span class="newWikiWord">#{CGI.escape(name)}</span>} 
      end
    else 
      if known_cdf 
        cdf_div(href, width, height, badge_path)
      else 
        %{<span class="newWikiWord">#{CGI.escape(name)}<a href="#{href}">?</a></span>} 
      end
    end    
  end

  def cdf_div(s, w, h, b)
    %{<div class="cdf_object" src="#{s}" width="#{w}" height="#{h}">} +
    %{<a href="http://www.wolfram.com/cdf-player/" title="Get the free Wolfram CDF } +
    %{Player"><img src="#{b}"/></a></div>}
  end

  def youtube_link(mode, name, text)
    re = /\s*(\d{1,4})\s*x\s*(\d{1,4})\s*/
    tt = re.match(text)
    if tt
      width = tt[1]
      height = tt[2]
    else
      width = '640'
      height = '390'
    end
    %{<div class='ytplayer' data-video-id='#{CGI.escape(name.strip)}' data-video-width='#{width}' data-video-height='#{height}'></div>}
  end

  def delete_link(mode, name, web_address, known_file)
    href = @controller.url_for :controller => 'file', :web => web_address,
        :action => 'delete', :id => name, :only_oath => true
    if mode == :show and known_file
      %{<span class="deleteWikiWord"><a href="#{href}">Delete #{name}</a></span>}
    else 
      %{<span class="deleteWikiWord">[[#{name}:delete]]</span>}
    end
  end

  private

    def bad_filename(name)
      "<span class='badWikiWord'>[[invalid filename: #{name}]]</span>"
    end

    def wikilink_for(mode, name, anchor_name, text, web_address)
      web = Web.find_by_address(web_address)
      action = web.published? && (web != @web || [:publish, :s5].include?(mode) ) ? 'published' : 'show'
      href = @controller.url_for :controller => 'wiki', :web => web_address, :action => action, 
            :id => name, :only_path => true
      title = web == @web ? '' : %{ title="#{web_address}"}
      %{<a class="existingWikiWord" href="#{href}#{'#'+anchor_name if anchor_name}"#{title}>#{text}</a>}
    end
    
    def html_ext
      @html_ext ||= @controller.method(:html_ext).call
      # Why method().call ? A Ruby 1.9.2preview1 bug:
      # http://redmine.ruby-lang.org/issues/show/1802
    end
end
