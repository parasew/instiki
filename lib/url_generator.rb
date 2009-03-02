require 'stringsupport'

class AbstractUrlGenerator

  def initialize(controller)
    raise 'Controller cannot be nil' if controller.nil?
    @controller = controller
  end

  # Create a link for the given page (or file) name and link text based
  # on the render mode in options and whether the page (file) exists
  # in the web.
  def make_link(name, web, text = nil, options = {})
    mode = (options[:mode] || :show).to_sym
    link_type = (options[:link_type] || :show).to_sym

    if (link_type == :show)
      known_page = web.has_page?(name)
    else
      known_page = web.has_file?(name)
      description = web.description(name)
      description = description.unescapeHTML.escapeHTML if description
    end
    if (text == name)
      text = description || text
    else
      text = text || description
    end
    text = (text || WikiWords.separate(name)).unescapeHTML.escapeHTML
    
    case link_type
    when :show
      page_link(mode, name, text, web.address, known_page)
    when :file
      file_link(mode, name, text, web.address, known_page, description)
    when :pic
      pic_link(mode, name, text, web.address, known_page)
    when :video
      video_link(mode, name, text, web.address, known_page)
    when :delete
      delete_link(mode, name, web.address, known_page)
    else
      raise "Unknown link type: #{link_type}"
    end
  end
  
end

class UrlGenerator < AbstractUrlGenerator

  private

  def file_link(mode, name, text, web_address, known_file, description)
    case mode
    when :export
      if known_file
        %{<a class="existingWikiWord" title="#{description}" href="#{CGI.escape(name)}.#{@controller.html_ext}">#{text}</a>}
      else 
        %{<span class="newWikiWord">#{text}</span>}
      end
    when :publish
      if known_file 
        href = @controller.url_for :controller => 'file', :web => web_address, :action => 'file', 
            :id => name
        %{<a class="existingWikiWord"  title="#{description}" href="#{href}">#{text}</a>}
      else 
        %{<span class="newWikiWord">#{text}</span>}
      end
    else 
      href = @controller.url_for :controller => 'file', :web => web_address, :action => 'file', 
          :id => name
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
        %{<a class="existingWikiWord" href="#{CGI.escape(name)}.#{@controller.html_ext}">#{text}</a>}
      else 
        %{<span class="newWikiWord">#{text}</span>} 
      end
    when :publish
      if known_page
        href = @controller.url_for :controller => 'wiki', :web => web_address, :action => 'published', 
            :id => name
        %{<a class="existingWikiWord" href="#{href}">#{text}</a>}
      else 
        %{<span class="newWikiWord">#{text}</span>} 
      end
    when :show
      if known_page
        href = @controller.url_for :controller => 'wiki', :web => web_address, :action => 'show', 
            :id => name
        %{<a class="existingWikiWord" href="#{href}">#{text}</a>}
      else 
        href = @controller.url_for :controller => 'wiki', :web => web_address, :action => 'new', 
            :id => name
        %{<span class="newWikiWord">#{text}<a href="#{href}">?</a></span>}
      end
    else 
      if known_page
        web = Web.find_by_address(web_address)
        action = web.published? ? 'published' : 'show'
        href = @controller.url_for :controller => 'wiki', :web => web_address, :action => action, 
            :id => name
        %{<a class="existingWikiWord" href="#{href}">#{text}</a>}
      else 
        href = @controller.url_for :controller => 'wiki', :web => web_address, :action => 'new', 
            :id => name
        %{<span class="newWikiWord">#{text}<a href="#{href}">?</a></span>}
      end
    end
  end

  def pic_link(mode, name, text, web_address, known_pic)
    href = @controller.url_for :controller => 'file', :web => web_address, :action => 'file',
      :id => name
    case mode
    when :export
      if known_pic 
        %{<img alt="#{text}" src="#{CGI.escape(name)}" />}
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

  def video_link(mode, name, text, web_address, known_vid)
    href = @controller.url_for :controller => 'file', :web => web_address, :action => 'file',
      :id => name
    case mode
    when :export
      if known_vid 
        %{<video src="#{CGI.escape(name)}" controls="controls">#{text}</video>}
      else 
        text
      end
    when :publish
      if known_vid
        %{<video src="#{href}" controls="controls">#{text}</video>}
      else 
        %{<span class="newWikiWord">#{text}</span>} 
      end
    else 
      if known_vid 
        %{<video src="#{href}" controls="controls">#{text}</video>}
      else 
        %{<span class="newWikiWord">#{text}<a href="#{href}">?</a></span>} 
      end
    end
  end

  def delete_link(mode, name, web_address, known_file)
    href = @controller.url_for :controller => 'file', :web => web_address,
        :action => 'delete', :id => name
    if mode == :show and known_file
      %{<span class="deleteWikiWord"><a href="#{href}">Delete #{name}</a></span>}
    else 
      %{<span class="deleteWikiWord">[[#{name}:delete]]</span>}
    end
  end
  
end
