#!/bin/env ruby -w

require File.dirname(__FILE__) + '/../test_helper'

require 'action_controller/routing'

class RoutesTest < Test::Unit::TestCase

  def test_parse_uri
    assert_routing('', :controller => 'wiki', :action => 'index')
    assert_routing('x', :controller => 'wiki', :action => 'index', :web => 'x')
    assert_routing('x/y', :controller => 'wiki', :web => 'x', :action => 'y')
    assert_routing('x/y/z', :controller => 'wiki', :web => 'x', :action => 'y', :id => 'z')
    assert_recognizes({:web => 'x', :controller => 'wiki', :action => 'y'}, 'x/y/')
    assert_recognizes({:web => 'x', :controller => 'wiki', :action => 'y', :id => 'z'}, 'x/y/z/')
  end
  
  def test_parse_uri_interestng_cases
    assert_routing('_veeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeery-long_web_/an_action/HomePage', 
      :web => '_veeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeery-long_web_', 
      :controller => 'wiki', 
      :action => 'an_action', :id => 'HomePage'
    )
    assert_recognizes({:controller => 'wiki', :action => 'index'}, '///')
  end
  
  def test_parse_uri_liberal_with_pagenames

    assert_routing('web/show/$HOME_PAGE', 
        :controller => 'wiki', :web => 'web', :action => 'show', :id => '$HOME_PAGE')
      
    assert_routing('web/show/HomePage?arg1=value1&arg2=value2', 
        :controller => 'wiki', :web => 'web', :action => 'show', 
        :id => 'HomePage?arg1=value1&arg2=value2')
    
    assert_routing('web/file/abc.zip', 
        :web => 'web', :controller => 'file', :action => 'file', :id => 'abc.zip')
    assert_routing('web/pic/abc.jpg', 
        :web => 'web', :controller => 'file', :action => 'pic', :id => 'abc.jpg')
    assert_routing('web/import', :web => 'web', :controller => 'file', :action => 'import')
    # default option is wiki
    assert_recognizes({:controller => 'wiki', :web => 'unknown_path', :action => 'index', }, 
      'unknown_path')
  end

  def test_cases_broken_by_routes
    assert_routing('web/show/HomePage/something_else', 
        :controller => 'wiki', :web => 'web', :action => 'show', :id => 'HomePage/something_else')
    assert_routing('web/show/Page+With+Spaces', 
        :controller => 'wiki', :web => 'web', :action => 'show', :id => 'Page+With+Spaces')
  end

end
