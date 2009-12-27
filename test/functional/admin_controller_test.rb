#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require 'admin_controller'

# Raise errors beyond the default web-based presentation
class AdminController; def rescue_action(e) logger.error(e); raise e end; end

class AdminControllerTest < ActionController::TestCase
  fixtures :webs, :pages, :revisions, :system, :wiki_references

  def setup
    require 'action_controller/test_process'
    @controller = AdminController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    class << @request.session
      attr_accessor :dbman
    end
    # simulate a cookie session store
    @request.session.dbman = FakeSessionDbMan
    @wiki = Wiki.new
    @oak = pages(:oak)
    @liquor = pages(:liquor)
    @elephant = pages(:elephant)
    @web = webs(:test_wiki)
    @home = @page = pages(:home_page)
    FileUtils.rm_rf("#{RAILS_ROOT}/webs/renamed_wiki1")
  end

  def test_create_system_form_displayed
    use_blank_wiki
    process('create_system')
    assert_response :success
  end

  def test_create_system_form_submitted
    use_blank_wiki
    assert !@wiki.setup?
    
    process('create_system', 'password' => 'a_password', 'web_name' => 'My Wiki', 
        'web_address' => 'my_wiki')
      
    assert_redirected_to :web => 'my_wiki', :controller => 'wiki', :action => 'new', 
        :id => 'HomePage'
    assert @wiki.setup?
    assert_equal 'a_password', @wiki.system[:password]
    assert_equal 1, @wiki.webs.size
    new_web = @wiki.webs['my_wiki']
    assert_equal 'My Wiki', new_web.name
    assert_equal 'my_wiki', new_web.address
  end

  def test_create_system_form_submitted_and_wiki_already_initialized
    wiki_before = @wiki
    old_size = @wiki.webs.size
    assert @wiki.setup?

    process 'create_system', 'password' => 'a_password', 'web_name' => 'My Wiki', 
        'web_address' => 'my_wiki'

    assert_redirected_to :web => @wiki.webs.keys.first, :controller => 'wiki', :action => 'show', :id => 'HomePage'
    assert_equal wiki_before, @wiki
    # and no new web should be created either
    assert_equal old_size, @wiki.webs.size
    assert(@response.has_flash_object?(:error))
  end

  def test_create_system_no_form_and_wiki_already_initialized
    assert @wiki.setup?
    process('create_system')
    assert_redirected_to :web => @wiki.webs.keys.first, :controller => 'wiki', :action => 'show', :id => 'HomePage'
    assert(@response.has_flash_object?(:error))
  end


  def test_create_web
    @wiki.system.update_attribute(:password, 'pswd')
  
    process 'create_web', 'system_password' => 'pswd', 'name' => 'Wiki Two', 'address' => 'wiki2'
    
    assert_redirected_to :web => 'wiki2', :controller => 'wiki', :action => 'new', :id => 'HomePage'
    wiki2 = @wiki.webs['wiki2']
    assert wiki2
    assert_equal 'Wiki Two', wiki2.name
    assert_equal 'wiki2', wiki2.address
  end

  def test_create_web_default_password
    @wiki.system.update_attribute(:password, nil)
  
    process 'create_web', 'system_password' => 'instiki', 'name' => 'Wiki Two', 'address' => 'wiki2'
    
    assert_redirected_to :web => 'wiki2', :controller => 'wiki', :action => 'new', :id => 'HomePage'
  end

  def test_create_web_failed_authentication
    @wiki.system.update_attribute(:password, 'pswd')
  
    process 'create_web', 'system_password' => 'wrong', 'name' => 'Wiki Two', 'address' => 'wiki2'
    
    assert_redirected_to :controller => 'admin', :action => 'create_web'
    assert_nil @wiki.webs['wiki2']
  end

  def test_create_web_no_form_submitted
    @wiki.system.update_attribute(:password, 'pswd')
    process 'create_web'
    assert_response :success
  end

  def test_edit_web_no_form
    process 'edit_web', 'web' => 'wiki1'
    # this action simply renders a form
    assert_response :success
  end

  def test_edit_web_form_submitted
    @wiki.system.update_attribute(:password, 'pswd')
    @web.save

    process('edit_web', 'system_password' => 'pswd',
        'web' => 'wiki1', 'address' => 'renamed_wiki1', 'name' => 'Renamed Wiki1',
        'markup' => 'markdown', 'color' => 'blue', 'additional_style' => 'whatever', 
        'safe_mode' => 'on', 'password' => 'new_password', 'password_check' => 'new_password', 'published' => 'on', 
        'brackets_only' => 'on', 'count_pages' => 'on', 'allow_uploads' => 'on',
        'max_upload_size' => '300')

    assert_redirected_to :web => 'renamed_wiki1', :controller => 'wiki', :action => 'show', :id => 'HomePage'
    @web = Web.find(@web.id)
    assert_equal 'renamed_wiki1', @web.address
    assert_equal 'Renamed Wiki1', @web.name
    assert_equal :markdown, @web.markup
    assert_equal 'blue', @web.color
    assert @web.safe_mode?
    assert_equal 'new_password', @web.password
    assert @web.published?
    assert @web.brackets_only?
    assert @web.count_pages?
    assert @web.allow_uploads?
    assert_equal 300, @web.max_upload_size
    assert File.directory? Rails.root.join("webs", "renamed_wiki1", "files")
    assert !File.exist?(Rails.root.join("webs", "renamed_wiki1", "wiki1"))
    assert !File.exist?(Rails.root.join("webs", "wiki1"))
  end

  def test_edit_web_web_password_mismatch
    @wiki.system.update_attribute(:password, 'pswd')
    @web.save

    process('edit_web', 'system_password' => 'pswd',
        'web' => 'wiki1', 'address' => 'renamed_wiki1', 'name' => 'Renamed Wiki1',
        'markup' => 'markdown', 'color' => 'blue', 'additional_style' => 'whatever', 
        'safe_mode' => 'on', 'password' => 'new_password', 'password_check' => 'old_password', 'published' => 'on', 
        'brackets_only' => 'on', 'count_pages' => 'on', 'allow_uploads' => 'on',
        'max_upload_size' => '300')

    assert_response :success
    assert @response.has_template_object?('error')
    assert File.directory? Rails.root.join("webs", "wiki1", "files")
    assert !File.exist?(Rails.root.join("webs", "renamed_wiki1", "wiki1"))
    assert !File.exist?(Rails.root.join("webs", "renamed_wiki1"))
  end

  def test_edit_web_opposite_values
    @wiki.system.update_attribute(:password, 'pswd')
    @web.save
  
    process('edit_web', 'system_password' => 'pswd',
        'web' => 'wiki1', 'address' => 'renamed_wiki1', 'name' => 'Renamed Wiki1',
        'markup' => 'markdown', 'color' => 'blue', 'additional_style' => 'whatever', 
        'password' => 'new_password', 'password_check' => 'new_password')
    # safe_mode, published, brackets_only, count_pages, allow_uploads not set 
    # and should become false

    assert_redirected_to :web => 'renamed_wiki1', :controller => 'wiki', :action => 'show', :id => 'HomePage'
    @web = Web.find(@web.id)
    assert !@web.safe_mode?
    assert !@web.published?
    assert !@web.brackets_only?
    assert !@web.count_pages?
    assert !@web.allow_uploads?
    assert File.directory? Rails.root.join("webs", "renamed_wiki1", "files")
    assert !File.exist?(Rails.root.join("webs", "renamed_wiki1", "wiki1"))
    assert !File.exist?(Rails.root.join("webs", "wiki1"))
  end

  def test_edit_web_wrong_password
    process('edit_web', 'system_password' => 'wrong',
      'web' => 'wiki1', 'address' => 'renamed_wiki1', 'name' => 'Renamed Wiki1',
      'markup' => 'markdown', 'color' => 'blue', 'additional_style' => 'whatever', 
      'password' => 'new_password')
      
    #returns to the same form
    assert_response :success
    assert @response.has_template_object?('error')
  end

  def test_edit_web_rename_to_already_existing_web_name
    @wiki.system.update_attribute(:password, 'pswd')
    
    @wiki.create_web('Another', 'another')
    process('edit_web', 'system_password' => 'pswd',
      'web' => 'wiki1', 'address' => 'another', 'name' => 'Renamed Wiki1',
      'markup' => 'markdown', 'color' => 'blue', 'additional_style' => 'whatever', 
      'password' => 'new_password', 'password_check' => 'new_password')
      
    #returns to the same form
    assert_response :success
    assert @response.has_template_object?('error')
  end

  def test_edit_web_empty_password
    process('edit_web', 'system_password' => '',
      'web' => 'wiki1', 'address' => 'renamed_wiki1', 'name' => 'Renamed Wiki1',
      'markup' => 'markdown', 'color' => 'blue', 'additional_style' => 'whatever', 
      'password' => 'new_password')
      
    #returns to the same form
    assert_response :success
    assert @response.has_template_object?('error')
  end


  def test_remove_orphaned_pages
    @wiki.system.update_attribute(:password, 'pswd')
    page_order = [@home, pages(:my_way), @oak, pages(:smart_engine), pages(:that_way), @liquor]
    x_test_renderer(@web.page('liquor').revisions.last).display_content(true)
    orphan_page_linking_to_oak_and_redirecting_to_liquor = @wiki.write_page('wiki1', 'Pine',
        "Refers to [[Oak]] and to [[booze]].\n" +
        "category: trees", 
        Time.now, Author.new('TreeHugger', '127.0.0.2'), x_test_renderer)
    
    r = process('remove_orphaned_pages', 'web' => 'wiki1', 'system_password_orphaned' => 'pswd')

    assert_redirected_to :controller => 'wiki', :web => 'wiki1', :action => 'list'
    @web.pages(true)
    assert_equal page_order, @web.select.sort,
        "Pages are not as expected: #{@web.select.sort.map {|p| p.name}.inspect}"

    # Oak is now orphan, second pass should remove it
    r = process('remove_orphaned_pages', 'web' => 'wiki1', 'system_password_orphaned' => 'pswd')
    assert_redirected_to :controller => 'wiki', :web => 'wiki1', :action => 'list'
    @web.pages(true)
    page_order.delete(@oak)
    page_order.delete(@liquor)
    assert_equal page_order, @web.select.sort,
        "Pages are not as expected: #{@web.select.sort.map {|p| p.name}.inspect}"

    # third pass does not destroy HomePage
    r = process('remove_orphaned_pages', 'web' => 'wiki1', 'system_password_orphaned' => 'pswd')
    assert_redirected_to  :web => 'wiki1', :controller => 'wiki', :action => 'list'
    @web.pages(true)
    assert_equal page_order, @web.select.sort,
        "Pages are not as expected: #{@web.select.sort.map {|p| p.name}.inspect}"
  end

  def test_remove_orphaned_pages_in_category
    @wiki.system.update_attribute(:password, 'pswd')
    page_order = [pages(:elephant), pages(:first_page), @home, pages(:my_way), pages(:no_wiki_word),
       @oak, pages(:smart_engine), pages(:that_way), @liquor]
    orphan_page_linking_to_oak = @wiki.write_page('wiki1', 'Pine',
        "Refers to [[Oak]].\n" +
        "category: trees", 
        Time.now, Author.new('TreeHugger', '127.0.0.2'), x_test_renderer)

    r = process('remove_orphaned_pages_in_category', 'web' => 'wiki1', 'category' => 'trees','system_password_orphaned_in_category' => 'pswd')

    assert_redirected_to :controller => 'wiki', :web => 'wiki1', :action => 'list'
    @web.pages(true)
    assert_equal page_order, @web.select.sort,
        "Pages are not as expected: #{@web.select.sort.map {|p| p.name}.inspect}"

    # Oak is now orphan, but it's not in the 'animals' category,
    # so the second pass should not remove it
    r = process('remove_orphaned_pages_in_category', 'web' => 'wiki1', 'category' => 'animals', 'system_password_orphaned_in_category' => 'pswd')
    assert_redirected_to :controller => 'wiki', :web => 'wiki1', :action => 'list'
    @web.pages(true)
    page_order.delete(pages(:elephant))
    assert_equal page_order, @web.select.sort,
        "Pages are not as expected: #{@web.select.sort.map {|p| p.name}.inspect}"

    # third pass does does nothing, since there are no pages in the
    # 'leaves' category.
    r = process('remove_orphaned_pages_in_category', 'web' => 'wiki1', 'category' => 'leaves', 'system_password_orphaned_in_category' => 'pswd')
    assert_redirected_to :controller => 'wiki', :web => 'wiki1', :action => 'list'
    @web.pages(true)
    assert_equal page_order, @web.select.sort,
        "Pages are not as expected: #{@web.select.sort.map {|p| p.name}.inspect}"

    # fourth pass destroys Oak
    r = process('remove_orphaned_pages_in_category', 'web' => 'wiki1', 'category' => 'trees', 'system_password_orphaned_in_category' => 'pswd')
    assert_redirected_to :controller => 'wiki', :web => 'wiki1', :action => 'list'
    @web.pages(true)
    page_order.delete(@oak)
    assert_equal page_order, @web.select.sort,
        "Pages are not as expected: #{@web.select.sort.map {|p| p.name}.inspect}"
  end
  
  def test_remove_orphaned_pages_empty_or_wrong_password
    @wiki.system[:password] = 'pswd'
    
    process('remove_orphaned_pages', 'web' => 'wiki1')
    assert_redirected_to(:controller => 'admin', :action => 'edit_web', :web => 'wiki1')
    assert @response.flash[:error]

    process('remove_orphaned_pages', 'web' => 'wiki1', 'system_password_orphaned' => 'wrong')
    assert_redirected_to(:controller => 'admin', :action => 'edit_web', :web => 'wiki1')
    assert @response.flash[:error]
  end
end
