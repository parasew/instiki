xml.feed('xmlns' => "http://www.w3.org/2005/Atom", "xml:lang" => 'en') do
  styles = { 'del.diffdel' => 'background-color:#FAA; text-decoration:line-through;', 'del.diffmod' => 'background-color:#FAA; text-decoration:line-through; border: 2px solid #FE0;', 'ins.diffins' => 'background-color:#AFA; text-decoration:underline;', 'ins.diffmod' => 'background-color:#AFA; text-decoration:underline; border: 2px solid #FE0;' }
  xml.title(@web.name + ' Changes')
  xml.link( 'rel' => 'alternate', 'type' => "application/xhtml+xml", 'href' =>  url_for(:only_path => false, :web => @web_name, :action => @link_action, :id => 'HomePage') )
  xml.link( 'rel' => 'self', 'href' =>  url_for(:only_path => false, :web => @web_name, :action => :atom_with_changes) )
  xml.updated(@web.revised_at.getgm.strftime("%Y-%m-%dT%H:%M:%SZ") )
  xml.id('tag:' + url_for(:only_path => false, :web => @web_name).split('/')[2].split(':')[0] + ',' + @web.created_at.getgm.strftime("%Y-%m-%d") + ':' + CGI.escape(@web.name) + '/changes' )
  xml.subtitle('An Instiki Wiki')
  xml.generator('Instiki', 'uri' => "http://golem.ph.utexas.edu/instiki/show/HomePage", 'version' => Instiki::VERSION::STRING)

  for revision in @revisions
    xml.entry do
      if revision.number > 1
        xml.title("%s (Revision %d)" % [ revision.page.plain_name, revision.number ])
      else
        xml.title(revision.page.plain_name)
      end
      xml.link('rel' => 'alternate', 'type' => 'application/xhtml+xml', 'href' => url_for(:only_path => false, :web => @web_name, :action => 'revision', :mode => 'diff', :id => revision.page.name, :rev => revision.number.to_s))
      xml.updated(revision.revised_at.getgm.strftime("%Y-%m-%dT%H:%M:%SZ") )
      xml.published(revision.created_at.getgm.strftime("%Y-%m-%dT%H:%M:%SZ") )
      xml.id('tag:' +url_for(:only_path => false, :web => @web_name).split('/')[2].split(':')[0]  + ',' + revision.created_at.getgm.strftime("%Y-%m-%d") + ':' + CGI.escape(@web.name) + '/revision/' + revision.id.to_s + '/' + CGI.escape(revision.page.name) + '/' + revision.number.to_s)
      xml.author do
        xml.name(revision.author)
      end
      xml.content('type' => 'xhtml', 'xml:base' => url_for(:only_path => false, :web => @web_name, :action => @link_action, :id => revision.page.name) ) do
        xml.div('xmlns' => 'http://www.w3.org/1999/xhtml' ) do
          xml.p('%s on %s by %s %s.' % [ (revision.number > 1) ? "Revised" : "Created", format_date(revision.revised_at), revision.author, revision.author.respond_to?(:ip) ? "(%s)" % revision.author.ip.to_s : "" ])
          if revision.number > 1
            xml.p << ' Changes are formatted as follows: <ins class="diffins" style="%s">Added</ins> | <del class="diffdel" style="%s">Removed</del> | <del class="diffmod" style="%s">Chan</del><ins class="diffmod" style="%s">ged</ins>' % [ styles['ins.diffins'], styles['del.diffdel'], styles['del.diffmod'], styles['ins.diffmod'] ]
          end
          xml.div << PageRenderer.new(revision).display_diff(styles)
        end
      end
    end
  end
end
