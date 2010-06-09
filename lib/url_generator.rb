require 'instiki_stringsupport'

class AbstractUrlGenerator

  def initialize(controller)
    raise 'Controller cannot be nil' if controller.nil?
    @controller = controller
  end

  # Create a link for the given page (or file) name and link text based
  # on the render mode in options and whether the page (file) exists
  # in the web.
  def make_link(current_web, asked_name, web, text = nil, options = {})
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
      page_link(mode, name, text, web.address, known_page)
    when :file
      file_link(mode, name, text, web.address, known_page, description)
    when :pic
      pic_link(mode, name, text, web.address, known_page)
    when :audio
      media_link(mode, name, text, web.address, known_page, 'audio')
    when :video
      media_link(mode, name, text, web.address, known_page, 'video')
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

  def page_link(mode, name, text, web_address, known_page)
    case mode
    when :export
      if known_page 
        %{<a class="existingWikiWord" href="#{CGI.escape(name)}.#{html_ext}">#{text}</a>}
      else 
        %{<span class="newWikiWord">#{text}</span>} 
      end
    when :publish
      if known_page
        wikilink_for(mode, name, text, web_address)
      else 
        %{<span class="newWikiWord">#{text}</span>} 
      end
    else 
      if known_page
        wikilink_for(mode, name, text, web_address)
      else 
        href = @controller.url_for :controller => 'wiki', :web => web_address, :action => 'new', 
            :id => name, :only_path => true
        %{<span class="newWikiWord">#{text}<a href="#{href}">?</a></span>}
      end
    end
  end

  def pic_link(mode, name, text, web_address, known_pic)
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

  def media_link(mode, name, text, web_address, known_media, media_type)
    href = @controller.url_for :controller => 'file', :web => web_address, :action => 'file',
      :id => name, :only_path => true
    case mode
    when :export
      if known_media 
        %{<#{media_type} src="files/#{CGI.escape(name)}" controls="controls">#{text}</#{media_type}>}
      else 
        text
      end
    when :publish
      if known_media
        %{<#{media_type} src="#{href}" controls="controls">#{text}</#{media_type}>}
      else 
        %{<span class="newWikiWord">#{text}</span>} 
      end
    else 
      if known_media 
        %{<#{media_type} src="#{href}" controls="controls">#{text}</#{media_type}>}
      else 
        %{<span class="newWikiWord">#{text}<a href="#{href}">?</a></span>} 
      end
    end
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

    def wikilink_for(mode, name, text, web_address)
      web = Web.find_by_address(web_address)
      action = web.published? && (web != @web || [:publish, :s5].include?(mode) ) ? 'published' : 'show'
      href = @controller.url_for :controller => 'wiki', :web => web_address, :action => action, 
            :id => name, :only_path => true
      title = web == @web ? '' : %{ title="#{web_address}"}
      %{<a class="existingWikiWord" href="#{href}"#{title}>#{text}</a>}
    end
    
    def html_ext
      @html_ext ||= @controller.method(:html_ext).call
      # Why method().call ? A Ruby 1.9.2preview1 bug:
      # http://redmine.ruby-lang.org/issues/show/1802
    end
end
