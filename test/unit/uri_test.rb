#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require 'chunks/uri'

class URITest < Test::Unit::TestCase
  include ChunkMatch

  def test_non_matches
    assert_conversion_does_not_apply(URIChunk, 'There is no URI here')
    assert_conversion_does_not_apply(URIChunk, 
        'One gemstone is the garnet:reddish in colour, like ruby') 
  end

  def test_simple_uri
    # Simplest case
    match(URIChunk, 'http://www.example.com',
		:scheme =>'http', :host =>'www.example.com', :path => nil,
		:link_text => 'http://www.example.com'
	)
	# With trailing slash
    match(URIChunk, 'http://www.example.com/',
		:scheme =>'http', :host =>'www.example.com', :path => '/',
		:link_text => 'http://www.example.com/'
	)
	# Without http://
    match(URIChunk, 'www.example.com', 
		:scheme =>'http', :host =>'www.example.com', :link_text => 'www.example.com'
	)
	# two parts
    match(URIChunk, 'example.com', 
		:scheme =>'http',:host =>'example.com', :link_text => 'example.com'
    )
	# "unusual" base domain (was a bug in an early version)
    match(URIChunk, 'http://example.com.au/', 
		:scheme =>'http', :host =>'example.com.au', :link_text => 'http://example.com.au/'
	)
	# "unusual" base domain without http://
    match(URIChunk, 'example.com.au',  
		:scheme =>'http', :host =>'example.com.au', :link_text => 'example.com.au'
	)
	# Another "unusual" base domain
    match(URIChunk, 'http://www.example.co.uk/',
		:scheme =>'http', :host =>'www.example.co.uk',
		:link_text => 'http://www.example.co.uk/'
	)
    match(URIChunk, 'example.co.uk',
		:scheme =>'http', :host =>'example.co.uk', :link_text => 'example.co.uk'
	)
	# With some path at the end
	match(URIChunk, 'http://moinmoin.wikiwikiweb.de/HelpOnNavigation',
		:scheme => 'http', :host => 'moinmoin.wikiwikiweb.de', :path => '/HelpOnNavigation',
		:link_text => 'http://moinmoin.wikiwikiweb.de/HelpOnNavigation'
	)
	# With some path at the end, and withot http:// prefix
	match(URIChunk, 'moinmoin.wikiwikiweb.de/HelpOnNavigation',
		:scheme => 'http', :host => 'moinmoin.wikiwikiweb.de', :path => '/HelpOnNavigation',
		:link_text => 'moinmoin.wikiwikiweb.de/HelpOnNavigation'
	)
	# With a port number
	match(URIChunk, 'http://www.example.com:80',
        :scheme =>'http', :host =>'www.example.com', :port => '80', :path => nil,
        :link_text => 'http://www.example.com:80')
	# With a port number and a path
	match(URIChunk, 'http://www.example.com.tw:80/HelpOnNavigation',
        :scheme =>'http', :host =>'www.example.com.tw', :port => '80', :path => '/HelpOnNavigation',
        :link_text => 'http://www.example.com.tw:80/HelpOnNavigation')
	# With a query
	match(URIChunk, 'http://www.example.com.tw:80/HelpOnNavigation?arg=val',
        :scheme =>'http', :host =>'www.example.com.tw', :port => '80', :path => '/HelpOnNavigation',
        :query => 'arg=val',
        :link_text => 'http://www.example.com.tw:80/HelpOnNavigation?arg=val')
	# Query with two arguments
	match(URIChunk, 'http://www.example.com.tw:80/HelpOnNavigation?arg=val&arg2=val2',
        :scheme =>'http', :host =>'www.example.com.tw', :port => '80', :path => '/HelpOnNavigation',
        :query => 'arg=val&arg2=val2',
        :link_text => 'http://www.example.com.tw:80/HelpOnNavigation?arg=val&arg2=val2')
	# HTTPS
	match(URIChunk, 'https://www.example.com',
        :scheme =>'https', :host =>'www.example.com', :port => nil, :path => nil, :query => nil,
        :link_text => 'https://www.example.com')
	# FTP
	match(URIChunk, 'ftp://www.example.com',
        :scheme =>'ftp', :host =>'www.example.com', :port => nil, :path => nil, :query => nil,
        :link_text => 'ftp://www.example.com')
	# mailto
	match(URIChunk, 'mailto:jdoe123@example.com',
        :scheme =>'mailto', :host =>'example.com', :port => nil, :path => nil, :query => nil,
        :user => 'jdoe123', :link_text => 'mailto:jdoe123@example.com')
    # something nonexistant
	match(URIChunk, 'foobar://www.example.com',
        :scheme =>'foobar', :host =>'www.example.com', :port => nil, :path => nil, :query => nil,
        :link_text => 'foobar://www.example.com')

    # Soap opera (the most complex case imaginable... well, not really, there should be more evil)
	match(URIChunk, 'http://www.example.com.tw:80/~jdoe123/Help%20Me%20?arg=val&arg2=val2',
        :scheme =>'http', :host =>'www.example.com.tw', :port => '80', 
        :path => '/~jdoe123/Help%20Me%20', :query => 'arg=val&arg2=val2',
        :link_text => 'http://www.example.com.tw:80/~jdoe123/Help%20Me%20?arg=val&arg2=val2')
 
    # from 0.9 bug reports 
    match(URIChunk, 'http://www2.pos.to/~tosh/ruby/rdtool/en/doc/rd-draft.html',
        :scheme =>'http', :host => 'www2.pos.to', 
        :path => '/~tosh/ruby/rdtool/en/doc/rd-draft.html')

    match(URIChunk, 'http://support.microsoft.com/default.aspx?scid=kb;en-us;234562',
        :scheme =>'http', :host => 'support.microsoft.com', :path => '/default.aspx',
        :query => 'scid=kb;en-us;234562')
  end

  def test_email_uri
	match(URIChunk, 'mail@example.com', 
		:user => 'mail', :host => 'example.com', :link_text => 'mail@example.com'
	)
  end

  def test_non_email
	# The @ is part of the normal text, but 'example.com' is marked up.
	match(URIChunk, 'Not an email: @example.com', :user => nil, :uri => 'http://example.com')
  end

  def test_textile_image
    assert_conversion_does_not_apply(URIChunk, 
             'This !http://hobix.com/sample.jpg! is a Textile image link.')
  end

  def test_textile_link
    assert_conversion_does_not_apply(URIChunk, 
             'This "hobix (hobix)":http://hobix.com/sample.jpg is a Textile link.')
    # just to be sure ...
    match(URIChunk, 'This http://hobix.com/sample.jpg should match', 
          :link_text => 'http://hobix.com/sample.jpg')
  end
  
  def test_inline_html
    assert_conversion_does_not_apply(URIChunk, '<IMG SRC="http://hobix.com/sample.jpg">')
    assert_conversion_does_not_apply(URIChunk, "<img src='http://hobix.com/sample.jpg'/>")
  end

  def test_non_uri
    # "so" is a valid country code; "libproxy.so" is a valid url
    match(URIChunk, 'libproxy.so', :link_text => 'libproxy.so')

    assert_conversion_does_not_apply URIChunk, 'httpd.conf'
    assert_conversion_does_not_apply URIChunk, 'ld.so.conf'
    assert_conversion_does_not_apply URIChunk, 'index.jpeg'
    assert_conversion_does_not_apply URIChunk, 'index.jpg'
    assert_conversion_does_not_apply URIChunk, 'file.txt'
    assert_conversion_does_not_apply URIChunk, 'file.doc'
    assert_conversion_does_not_apply URIChunk, 'file.pdf'
    assert_conversion_does_not_apply URIChunk, 'file.png'
    assert_conversion_does_not_apply URIChunk, 'file.ps'
  end

  def test_uri_in_text
    match(URIChunk, 'Go to: http://www.example.com/', :host => 'www.example.com', :path =>'/')
    match(URIChunk, 'http://www.example.com/ is a link.', :host => 'www.example.com')
    match(URIChunk, 
        'Email david@loudthinking.com', 
        :scheme =>'mailto', :user =>'david', :host =>'loudthinking.com')
    # check that trailing punctuation is not included in the hostname
    match(URIChunk, 'Hey dude, http://fake.link.com.', :scheme => 'http', :host => 'fake.link.com')
    # this is a textile link, no match please.
    assert_conversion_does_not_apply(URIChunk, '"link":http://fake.link.com.')
   end

  def test_uri_in_parentheses
    match(URIChunk, 'URI (http://brackets.com.de) in brackets', :host => 'brackets.com.de')
    match(URIChunk, 'because (as shown at research.net) the results', :host => 'research.net')
    match(URIChunk, 
      'A wiki (http://wiki.org/wiki.cgi?WhatIsWiki) page', 
      :scheme => 'http', :host => 'wiki.org', :path => '/wiki.cgi', :query => 'WhatIsWiki'
    )
  end
  
  def test_uri_list_item
    match(
      URIChunk, 
      '* http://www.btinternet.com/~mail2minh/SonyEricssonP80xPlatform.sis', 
      :path => '/~mail2minh/SonyEricssonP80xPlatform.sis'
    )
  end
  
  def test_interesting_uri_with__comma
    # Counter-intuitively, this URL matches, but the query part includes the trailing comma.
    # It has no way to know that the query does not include the comma.
    match(
        URIChunk, 
        "This text contains a URL http://someplace.org:8080/~person/stuff.cgi?arg=val, doesn't it?",
        :scheme => 'http', :host => 'someplace.org', :port => '8080', :path => '/~person/stuff.cgi',
        :query => 'arg=val,')
  end
  
  def test_local_urls
    # normal
    match(LocalURIChunk, 'http://perforce:8001/toto.html', 
          :scheme => 'http', :host => 'perforce', 
          :port => '8001', :link_text => 'http://perforce:8001/toto.html')

    # in parentheses
    match(LocalURIChunk, 'URI (http://localhost:2500) in brackets', 
          :host => 'localhost', :port => '2500')
    match(LocalURIChunk, 'because (as shown at http://perforce:8001) the results', 
          :host => 'perforce', :port => '8001')
    match(LocalURIChunk, 
      'A wiki (http://localhost:2500/wiki.cgi?WhatIsWiki) page', 
          :scheme => 'http', :host => 'localhost', :path => '/wiki.cgi', 
          :port => '2500', :query => 'WhatIsWiki')
  end

  def assert_conversion_does_not_apply(chunk_type, str)
    processed_str = ContentStub.new(str.dup)
    chunk_type.apply_to(processed_str)
    assert_equal(str, processed_str)
  end

end
