#!/bin/env ruby -w

require File.dirname(__FILE__) + '/../test_helper'
require 'url_rewriting_hack'

class UrlRewritingHackTest < Test::Unit::TestCase
  
  def test_parse_uri
    assert_equal({:controller => 'wiki', :action => 'x', :web => nil}, 
        DispatchServlet.parse_uri('/x/'))
    assert_equal({:web => 'x', :controller => 'wiki', :action => 'y'}, 
        DispatchServlet.parse_uri('/x/y'))
    assert_equal({:web => 'x', :controller => 'wiki', :action => 'y'}, 
        DispatchServlet.parse_uri('/x/y/'))
    assert_equal({:web => 'x', :controller => 'wiki', :action => 'y', :id => 'z'}, 
        DispatchServlet.parse_uri('/x/y/z'))
    assert_equal({:web => 'x', :controller => 'wiki', :action => 'y', :id => 'z'}, 
        DispatchServlet.parse_uri('/x/y/z/'))
  end
  
  def test_parse_uri_approot
    assert_equal({:controller => 'wiki', :action => 'index', :web => nil}, 
        DispatchServlet.parse_uri('/wiki/'))
  end

  def test_parse_uri_interestng_cases

    assert_equal({:web => '_veeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeery-long_web_', 
          :controller => 'wiki', 
          :action => 'an_action', :id => 'HomePage'
        }, 
        DispatchServlet.parse_uri(
            '/_veeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeery-long_web_/an_action/HomePage')
    )

    assert_equal false, DispatchServlet.parse_uri('')
    assert_equal false, DispatchServlet.parse_uri('//')
    assert_equal false, DispatchServlet.parse_uri('web')
  end
  
  def test_parse_uri_liberal_with_pagenames

    assert_equal({:controller => 'wiki', :web => 'web', :action => 'show', :id => '$HOME_PAGE'}, 
      DispatchServlet.parse_uri('/web/show/$HOME_PAGE'))
      
    assert_equal({:controller => 'wiki', :web => 'web', :action => 'show', 
        :id => 'HomePage/something_else'}, 
        DispatchServlet.parse_uri('/web/show/HomePage/something_else'))
    
    assert_equal({:controller => 'wiki', :web => 'web', :action => 'show', 
        :id => 'HomePage?arg1=value1&arg2=value2'}, 
        DispatchServlet.parse_uri('/web/show/HomePage?arg1=value1&arg2=value2'))
    
    assert_equal({:controller => 'wiki', :web => 'web', :action => 'show', 
        :id => 'Page+With+Spaces'}, 
        DispatchServlet.parse_uri('/web/show/Page+With+Spaces'))
  end

  def test_url_rewriting
    request = ActionController::TestRequest.new
    ur = ActionController::UrlRewriter.new(request, 'wiki', 'show')

    assert_equal 'http://test.host/myweb/myaction',
        ur.rewrite(:web => 'myweb', :controller => 'wiki', :action => 'myaction')

    assert_equal 'http://test.host/myOtherWeb/',
        ur.rewrite(:web => 'myOtherWeb', :controller => 'wiki')

    assert_equal 'http://test.host/myaction',
        ur.rewrite(:controller => 'wiki', :action => 'myaction')

    assert_equal 'http://test.host/',
        ur.rewrite(:controller => 'wiki')
  end
  
  def test_controller_mapping
    request = ActionController::TestRequest.new
    ur = ActionController::UrlRewriter.new(request, 'wiki', 'show')

    assert_equal 'http://test.host/file',
        ur.rewrite(:controller => 'file', :action => 'file')
    assert_equal 'http://test.host/pic/abc.jpg',
        ur.rewrite(:controller => 'file', :action => 'pic', :id => 'abc.jpg')
    assert_equal 'http://test.host/web/pic/abc.jpg',
        ur.rewrite(:web => 'web', :controller => 'file', :action => 'pic', :id => 'abc.jpg')
        
    # default option is wiki
    assert_equal 'http://test.host/unknown_action',
        ur.rewrite(:controller => 'wiki', :action => 'unknown_action')
  end

end