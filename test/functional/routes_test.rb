#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class RoutesTest < ActionController::TestCase

  def test_parse_uri
    # Rails 7 removes the dynamic :action segment, so each wiki action is now
    # routed explicitly. The original test exercised arbitrary :action values
    # (y, an_action). Substitute a real action (show) — the parser behavior
    # being checked (special chars, encoded slashes, dot-segments in :id) is
    # independent of which action is named.
    assert_routing('', :controller => 'wiki', :action => 'index')
    assert_routing('x', :controller => 'wiki', :action => 'index', :web => 'x')
    assert_routing('x/show', :controller => 'wiki', :web => 'x', :action => 'show')
    assert_routing('x/show/z', :controller => 'wiki', :web => 'x', :action => 'show', :id => 'z')
    assert_recognizes({:web => 'x', :controller => 'wiki', :action => 'show'}, 'x/show/')
    assert_recognizes({:web => 'x', :controller => 'wiki', :action => 'show', :id => 'z'}, 'x/show/z')
    assert_recognizes({:web => 'x', :controller => 'wiki', :action => 'show', :id => 'z'}, 'x/show/z/')
    assert_recognizes({:web => 'x', :controller => 'wiki', :action => 'show', :id => 'z/'}, 'x/show/z%2F')
    assert_recognizes({:web => 'x', :controller => 'wiki', :action => 'show', :id => 'z.w'}, 'x/show/z.w')
  end

  def test_parse_uri_interestng_cases
    assert_routing('_veeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeery-long_web_/show/HomePage',
      :web => '_veeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeery-long_web_',
      :controller => 'wiki',
      :action => 'show', :id => 'HomePage'
    )
#    assert_recognizes({:controller => 'wiki', :action => 'index'}, '///')
  end
  
  def test_parse_uri_liberal_with_pagenames

    # Rails 6 keeps '$' unencoded in URLs (RFC 3986 reserves it as a sub-delim
    # but it's safe in path segments). The original test required percent-encoding.
    assert_routing('web/show/$HOME_PAGE',
        :controller => 'wiki', :web => 'web', :action => 'show', :id => '$HOME_PAGE')
        
#    assert_routing('web/show/HomePage%3F', 
#        :controller => 'wiki', :web => 'web', :action => 'show', 
#        :id => 'HomePage')
        
#    assert_routing('web/show/HomePage%3Farg1%3Dvalue1%26arg2%3Dvalue2', 
#        :controller => 'wiki', :web => 'web', :action => 'show', 
#        :id => 'HomePage?arg1=value1&arg2=value2')
    
    assert_routing('web/files/abc.zip',
        :web => 'web', :controller => 'file', :action => 'file', :id => 'abc.zip')
    assert_routing('web/import', :web => 'web', :controller => 'file', :action => 'import')
    # default option is wiki
    assert_recognizes({:controller => 'wiki', :web => 'unknown_path', :action => 'index', }, 
      'unknown_path')
  end

  def test_cases_broken_by_routes
    # Rails 6 treats '+' literally in URL paths (only in query strings is it
    # space-encoded). Use %20 to encode space in path segments.
    assert_routing('web/show/Page%20With%20Spaces',
       :controller => 'wiki', :web => 'web', :action => 'show', :id => 'Page With Spaces')
#    assert_routing('web/show/HomePage%2Fsomething_else', 
#        :controller => 'wiki', :web => 'web', :action => 'show', :id => 'HomePage/something_else')
  end

end
