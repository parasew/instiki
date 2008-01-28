xml.feed('xmlns' => "http://www.w3.org/2005/Atom", "xml:lang" => 'en') do
  xml.title(@web.name)
  xml.link( 'rel' => 'alternate', 'type' => "application/xhtml+xml", 'href' =>  url_for(:only_path => false, :web => @web_name, :action => @link_action, :id => 'HomePage') )
  xml.link( 'rel' => 'self', 'href' =>  url_for(:only_path => false, :web => @web_name, :action => @hide_description? :atom_with_headlines : :atom_with_content ) )
  xml.updated(@web.revised_at.getgm.strftime("%Y-%m-%dT%H:%M:%SZ") )
  xml.id('tag:' + url_for(:only_path => false, :web => @web_name).split('/')[2].split(':')[0] + ',' + @web.created_at.getgm.strftime("%Y-%m-%d") + ':' + CGI.escape(@web.name)  )
  xml.subtitle('An Instiki Wiki')
  xml.generator('Instiki', 'uri' => "http://golem.ph.utexas.edu/instiki/show/HomePage", 'version' => Instiki::VERSION::STRING)

  for page in @pages_by_revision
    xml.entry do
     xml.title(page.plain_name, 'type' => "html")
      xml.link('rel' => 'alternate', 'type' => 'application/xhtml+xml', 'href' => url_for(:only_path => false, :web => @web_name, :action => @link_action, :id => page.name) )
      xml.updated(page.revised_at.getgm.strftime("%Y-%m-%dT%H:%M:%SZ") )
      xml.published(page.created_at.getgm.strftime("%Y-%m-%dT%H:%M:%SZ") )
      xml.id('tag:' +url_for(:only_path => false, :web => @web_name).split('/')[2].split(':')[0]  + ',' + page.created_at.getgm.strftime("%Y-%m-%d") + ":"  + @web.name + ',' + CGI.escape(page.name)) 
      xml.author do
        xml.name(page.author)
      end
      if @hide_description
        xml.summary("Updated by #{page.author} on #{page.revised_at.getgm.strftime("%Y-%m-%d")} at #{page.revised_at.getgm.strftime("%H:%M:%SZ")}.", 'type' => 'text')
      else
        xml.content('type' => 'xhtml', 'xml:base' => url_for(:only_path => false, :web => @web_name, :action => @link_action, :id => page.name) ) do
          xml.div('xmlns' => 'http://www.w3.org/1999/xhtml' ) do
            |x| x << rendered_content(page)
          end
        end
      end
    end
  end
end
