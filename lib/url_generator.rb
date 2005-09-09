class UrlGenerator

  def initialize(controller = nil)
    @controller = controller or ControllerStub.new
  end

  def make_file_link(mode, name, text, base_url, known_file)
    link = CGI.escape(name)
    case mode
    when :export
      if known_file then "<a class=\"existingWikiWord\" href=\"#{link}.html\">#{text}</a>"
      else "<span class=\"newWikiWord\">#{text}</span>" end
    when :publish
      if known_file then "<a class=\"existingWikiWord\" href=\"#{base_url}/published/#{link}\">#{text}</a>"
      else "<span class=\"newWikiWord\">#{text}</span>" end
    else 
      if known_file
        "<a class=\"existingWikiWord\" href=\"#{base_url}/file/#{link}\">#{text}</a>"
      else 
        "<span class=\"newWikiWord\">#{text}<a href=\"#{base_url}/file/#{link}\">?</a></span>"
      end
    end
  end

  def make_page_link(mode, name, text, base_url, known_page)
    link = CGI.escape(name)
    case mode.to_sym
    when :export
      if known_page then %{<a class="existingWikiWord" href="#{link}.html">#{text}</a>}
      else %{<span class="newWikiWord">#{text}</span>} end
    when :publish
      if known_page then %{<a class="existingWikiWord" href="#{base_url}/published/#{link}">#{text}</a>}
      else %{<span class="newWikiWord">#{text}</span>} end
    else 
      if known_page
        %{<a class="existingWikiWord" href="#{base_url}/show/#{link}">#{text}</a>}
      else 
        %{<span class="newWikiWord">#{text}<a href="#{base_url}/show/#{link}">?</a></span>}
      end
    end
  end

  def make_pic_link(mode, name, text, base_url, known_pic)
    link = CGI.escape(name)
    case mode.to_sym
    when :export
      if known_pic then %{<img alt="#{text}" src="#{link}" />}
      else %{<img alt="#{text}" src="no image" />} end
    when :publish
      if known_pic then %{<img alt="#{text}" src="#{link}" />}
      else %{<span class="newWikiWord">#{text}</span>} end
    else 
      if known_pic then %{<img alt="#{text}" src="#{base_url}/pic/#{link}" />}
      else %{<span class="newWikiWord">#{text}<a href="#{base_url}/pic/#{link}">?</a></span>} end
    end
  end

end

class ControllerStub
end