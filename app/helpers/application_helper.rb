# The methods added to this helper will be available to all templates in the application.
module ApplicationHelper
require 'instiki_stringsupport'

  # Accepts a container (hash, array, enumerable, your type) and returns a string of option tags. Given a container 
  # where the elements respond to first and last (such as a two-element array), the "lasts" serve as option values and
  # the "firsts" as option text. Hashes are turned into this form automatically, so the keys become "firsts" and values
  # become lasts. If +selected+ is specified, the matching "last" or element will get the selected option-tag.
  #
  # Examples (call, result):
  #   html_options([["Dollar", "$"], ["Kroner", "DKK"]])
  #     <option value="$">Dollar</option>\n<option value="DKK">Kroner</option>
  #
  #   html_options([ "VISA", "Mastercard" ], "Mastercard")
  #     <option>VISA</option>\n<option selected>Mastercard</option>
  #
  #   html_options({ "Basic" => "$20", "Plus" => "$40" }, "$40")
  #     <option value="$20">Basic</option>\n<option value="$40" selected>Plus</option>
  def html_options(container, selected = nil)
    container = container.to_a if Hash === container
  
    html_options = container.inject([]) do |options, element| 
      if element.is_a? Array
        if element.last != selected
          options << "<option value=\"#{element.last}\">#{element.first}</option>"
        else
          options << "<option value=\"#{element.last}\" selected=\"selected\">#{element.first}</option>"
        end
      else
        options << ((element != selected) ? "<option>#{element}</option>" : "<option selected>#{element}</option>")
      end
    end
    
    html_options.join("\n").html_safe
  end

  # Creates a hyperlink to a Wiki page, without checking if the page exists or not
  def link_to_existing_page(page, text = nil, html_options = {})
    link_to(
        text || page.plain_name, 
        {:web => @web.address, :action => 'show', :id => page.name, :only_path => true},
        html_options).html_safe
  end
  
  # Creates a hyperlink to a Wiki page, or to a "new page" form if the page doesn't exist yet
  def link_to_page(page_name, web = @web, text = nil, options = {})
    raise 'Web not defined' if web.nil?
    UrlGenerator.new(@controller).make_link(@web, page_name, web, text, 
        options.merge(:base_url => "#{base_url}/#{web.address}")).html_safe
  end

  def author_link(page, options = {})
    UrlGenerator.new(@controller).make_link(@web, page.author.name, page.web, nil, options).purify.html_safe
  end

  # Create a hyperlink to a particular revision of a Wiki page
  def link_to_revision(page, revision_number, text = nil, mode = nil, html_options = {})
    revision_number == page.revisions.size ?
      link_to(
        text || page.plain_name,
            {:web => @web.address, :action => 'show', :id => page.name,
               :mode => mode}, html_options).html_safe :
      link_to(
        text || page.plain_name + "(rev # #{revision_number})".html_safe,
            {:web => @web.address, :action => 'revision', :id => page.name,
              :rev => revision_number, :mode => mode}, html_options).html_safe
  end

  # Create a hyperlink to the history of a particular Wiki page
  def link_to_history(page, text = nil, html_options = {})
    link_to(
        text || page.plain_name + "(history)".html_safe,
            {:web => @web.address, :action => 'history', :id => page.name},
            html_options).html_safe
  end

  def base_url
    home_page_url = url_for :controller => 'admin', :action => 'create_system', :only_path => true
    home_page_url.sub(%r-/create_system/?$-, '')
  end

  # Creates a menu of categories
  def categories_menu
    if @categories.empty?
      ''
    else 
      ("<div id=\"categories\">\n" +
      '<strong>Categories</strong>:' +
      '[' + link_to_unless_current('Any', :web => @web.address, :action => self.action_name, :category => nil) + "]\n" +
      @categories.map { |c| 
        link_to_unless_current(c.html_safe, :web => @web.address, :action => self.action_name, :category => c)
      }.join(', ') + "\n" +
      '</div>').html_safe
    end
  end

  # Performs HTML escaping on text, but keeps linefeeds intact (by replacing them with <br/>)
  def escape_preserving_linefeeds(text)
    h(text).gsub(/\n/, '<br/>').as_utf8
  end

  def format_date(date, include_time = true)
    # Must use DateTime because Time doesn't support %e on at least some platforms
    if include_time
      DateTime.new(date.year, date.mon, date.day, date.hour, date.min, date.sec).strftime("%B %e, %Y %H:%M:%S")
    else
      DateTime.new(date.year, date.mon, date.day).strftime("%B %e, %Y")
    end
  end

  def rendered_content(page)
    PageRenderer.new(page.revisions.last).display_content
  end

  def truncate(text, *args)
    options = args.extract_options!
    options.reverse_merge!(:length => 30, :omission => "...")
    return text.html_safe if text.num_chars <= options[:length]
    len = options[:length] - options[:omission].as_utf8.num_chars
    t = ''
    text.split.collect do |word|
      if t.num_chars + word.num_chars <= len
        t << word + ' '
      else 
        return (t.chop + options[:omission]).html_safe
      end
    end
  end

end
