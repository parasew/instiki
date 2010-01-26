#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

require 'action_controller/routing'

class RoutesTest < ActionController::TestCase

  def test_parse_uri
    assert_routing('', :controller => 'wiki', :action => 'index')
    assert_routing('x', :controller => 'wiki', :action => 'index', :web => 'x')
    assert_routing('x/y', :controller => 'wiki', :web => 'x', :action => 'y')
    assert_routing('x/y/z', :controller => 'wiki', :web => 'x', :action => 'y', :id => 'z')
    assert_recognizes({:web => 'x', :controller => 'wiki', :action => 'y'}, 'x/y/')
    assert_recognizes({:web => 'x', :controller => 'wiki', :action => 'y', :id => 'z'}, 'x/y/z')
    assert_recognizes({:web => 'x', :controller => 'wiki', :action => 'y', :id => 'z/'}, 'x/y/z/')
    assert_recognizes({:web => 'x', :controller => 'wiki', :action => 'y', :id => 'z/'}, 'x/y/z%2F')
    assert_recognizes({:web => 'x', :controller => 'wiki', :action => 'y', :id => 'z.w'}, 'x/y/z.w')
  end
  
  def test_parse_uri_interestng_cases
    assert_routing('_veeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeery-long_web_/an_action/HomePage', 
      :web => '_veeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeery-long_web_', 
      :controller => 'wiki', 
      :action => 'an_action', :id => 'HomePage'
    )
#    assert_recognizes({:controller => 'wiki', :action => 'index'}, '///')
  end
  
  def test_parse_uri_liberal_with_pagenames

    assert_routing('web/show/%24HOME_PAGE', 
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
   assert_routing('web/show/Page+With+Spaces', 
       :controller => 'wiki', :web => 'web', :action => 'show', :id => 'Page With Spaces')
#    assert_routing('web/show/HomePage%2Fsomething_else', 
#        :controller => 'wiki', :web => 'web', :action => 'show', :id => 'HomePage/something_else')
  end

end
