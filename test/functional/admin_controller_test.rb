#!/bin/env ruby -w 

require File.dirname(__FILE__) + '/../test_helper'
require 'admin_controller'

# Raise errors beyond the default web-based presentation
class AdminController; def rescue_action(e) logger.error(e); raise e end; end

class AdminControllerTest < Test::Unit::TestCase

  def setup
    setup_test_wiki
    setup_controller_test
  end

  def tear_down
    tear_down_wiki
  end


  def test_create_system_form_displayed
    ApplicationController.wiki = WikiServiceWithNoPersistence.new
    process('create_system')
    assert_success
  end

  def test_create_system_form_submitted
    ApplicationController.wiki = WikiServiceWithNoPersistence.new
    assert !ApplicationController.wiki.setup?
    
    process('create_system', 'password' => 'a_password', 'web_name' => 'My Wiki', 
        'web_address' => 'my_wiki')
      
    assert_redirected_to :web => 'my_wiki', :controller => 'wiki', :action => 'new', 
        :id => 'HomePage'
    assert ApplicationController.wiki.setup?
    assert_equal 'a_password', ApplicationController.wiki.system[:password]
    assert_equal 1, ApplicationController.wiki.webs.size
    new_web = ApplicationController.wiki.webs['my_wiki']
    assert_equal 'My Wiki', new_web.name
    assert_equal 'my_wiki', new_web.address
  end

  def test_create_system_form_submitted_and_wiki_already_initialized
    wiki_before = ApplicationController.wiki
    assert ApplicationController.wiki.setup?

    process 'create_system', 'password' => 'a_password', 'web_name' => 'My Wiki', 
        'web_address' => 'my_wiki'

    assert_redirected_to :web => 'wiki1', :action => 'show', :id => 'HomePage'
    assert_equal wiki_before, ApplicationController.wiki
    # and no new web should be created either
    assert_equal 1, ApplicationController.wiki.webs.size
    assert_flash_has :error
  end

  def test_create_system_no_form_and_wiki_already_initialized
    assert @wiki.setup?
    process('create_system')
    assert_redirected_to :web => 'wiki1', :action => 'show', :id => 'HomePage'
    assert_flash_has :error
  end


  def test_create_web
    @wiki.system[:password] = 'pswd'
  
    process 'create_web', 'system_password' => 'pswd', 'name' => 'Wiki Two', 'address' => 'wiki2'
    
    assert_redirected_to :web => 'wiki2', :action => 'show', :id => 'HomePage'
    wiki2 = @wiki.webs['wiki2']
    assert wiki2
    assert_equal 'Wiki Two', wiki2.name
    assert_equal 'wiki2', wiki2.address
  end

  def test_create_web_default_password
    @wiki.system[:password] = nil
  
    process 'create_web', 'system_password' => 'instiki', 'name' => 'Wiki Two', 'address' => 'wiki2'
    
    assert_redirected_to :web => 'wiki2', :action => 'show', :id => 'HomePage'
  end

  def test_create_web_failed_authentication
    @wiki.system[:password] = 'pswd'
  
    process 'create_web', 'system_password' => 'wrong', 'name' => 'Wiki Two', 'address' => 'wiki2'
    
    assert_redirected_to :web => nil, :action => 'index'
    assert_nil @wiki.webs['wiki2']
  end

  def test_create_web_no_form_submitted
    @wiki.system[:password] = 'pswd'
    process 'create_web'
    assert_success
  end

  def test_create_web_no_form_submitted_and_no_password_set
    @wiki.system[:password] = nil
    process 'create_web'
    assert_redirected_to :action => 'index'
  end


  def test_edit_web_no_form
    process 'edit_web', 'web' => 'wiki1'
    # this action simply renders a form
    assert_success
  end

  def test_edit_web_form_submitted
    @wiki.system[:password] = 'pswd'
  
    process('edit_web', 'system_password' => 'pswd',
        'web' => 'wiki1', 'address' => 'renamed_wiki1', 'name' => 'Renamed Wiki1',
        'markup' => 'markdown', 'color' => 'blue', 'additional_style' => 'whatever', 
        'safe_mode' => 'on', 'password' => 'new_password', 'published' => 'on', 
        'brackets_only' => 'on', 'count_pages' => 'on', 'allow_uploads' => 'on',
        'max_upload_size' => '300')

    assert_redirected_to :web => 'renamed_wiki1', :action => 'show', :id => 'HomePage'
    assert_equal 'renamed_wiki1', @web.address
    assert_equal 'Renamed Wiki1', @web.name
    assert_equal :markdown, @web.markup
    assert_equal 'blue', @web.color
    assert @web.safe_mode
    assert_equal 'new_password', @web.password
    assert @web.published
    assert @web.brackets_only
    assert @web.count_pages
    assert @web.allow_uploads
    assert_equal 300, @web.max_upload_size
  end

  def test_edit_web_opposite_values
    @wiki.system[:password] = 'pswd'
  
    process('edit_web', 'system_password' => 'pswd',
        'web' => 'wiki1', 'address' => 'renamed_wiki1', 'name' => 'Renamed Wiki1',
        'markup' => 'markdown', 'color' => 'blue', 'additional_style' => 'whatever', 
        'password' => 'new_password')
    # safe_mode, published, brackets_only, count_pages, allow_uploads not set 
    # and should become false

    assert_redirected_to :web => 'renamed_wiki1', :action => 'show', :id => 'HomePage'
    assert !@web.safe_mode
    assert !@web.published
    assert !@web.brackets_only
    assert !@web.count_pages
    assert !@web.allow_uploads
  end

  def test_edit_web_wrong_password
    process('edit_web', 'system_password' => 'wrong',
      'web' => 'wiki1', 'address' => 'renamed_wiki1', 'name' => 'Renamed Wiki1',
      'markup' => 'markdown', 'color' => 'blue', 'additional_style' => 'whatever', 
      'password' => 'new_password')
      
    #returns to the same form
    assert_success
    assert_flash_has :error
  end

  def test_edit_web_rename_to_already_existing_web_name
    @wiki.system[:password] = 'pswd'
    
    @wiki.create_web('Another', 'another')
    process('edit_web', 'system_password' => 'pswd',
      'web' => 'wiki1', 'address' => 'another', 'name' => 'Renamed Wiki1',
      'markup' => 'markdown', 'color' => 'blue', 'additional_style' => 'whatever', 
      'password' => 'new_password')
      
    #returns to the same form
    assert_success
    assert_flash_has :error
  end

  def test_edit_web_empty_password
    process('edit_web', 'system_password' => '',
      'web' => 'wiki1', 'address' => 'renamed_wiki1', 'name' => 'Renamed Wiki1',
      'markup' => 'markdown', 'color' => 'blue', 'additional_style' => 'whatever', 
      'password' => 'new_password')
      
    #returns to the same form
    assert_success
    assert_flash_has :error
  end


  def test_remove_orphaned_pages
    setup_wiki_with_three_pages
    @wiki.system[:password] = 'pswd'
    orhan_page_linking_to_oak = @wiki.write_page('wiki1', 'Pine',
        "Refers to [[Oak]].\n" +
        "category: trees", 
        Time.now, Author.new('TreeHugger', '127.0.0.2'))

    r = process('remove_orphaned_pages', 'web' => 'wiki1', 'system_password_orphaned' => 'pswd')

    assert_redirected_to :controller => 'wiki', :web => 'wiki1', :action => 'list'
    assert_equal [@home, @oak], @web.select.sort,
        "Pages are not as expected: #{@web.select.sort.map {|p| p.name}.inspect}"


    # Oak is now orphan, second pass should remove it
    r = process('remove_orphaned_pages', 'web' => 'wiki1', 'system_password_orphaned' => 'pswd')
    assert_redirected_to :controller => 'wiki', :web => 'wiki1', :action => 'list'
    assert_equal [@home], @web.select.sort,
        "Pages are not as expected: #{@web.select.sort.map {|p| p.name}.inspect}"

    # third pass does not destroy HomePage
    r = process('remove_orphaned_pages', 'web' => 'wiki1', 'system_password_orphaned' => 'pswd')
    assert_redirected_to :action => 'list'
    assert_equal [@home], @web.select.sort,
        "Pages are not as expected: #{@web.select.sort.map {|p| p.name}.inspect}"
  end

end
