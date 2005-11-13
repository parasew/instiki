#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../test_helper'
require 'file_controller'
require 'fileutils'
require 'stringio'

# Raise errors beyond the default web-based presentation
class FileController; def rescue_action(e) logger.error(e); raise e end; end

class FileControllerTest < Test::Unit::TestCase
  fixtures :webs, :pages, :revisions, :system

  def setup
    @controller = FileController.new
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    @web = webs(:test_wiki)
    WikiFile.delete_all
    require 'fileutils'
    FileUtils.rm_rf("#{RAILS_ROOT}/public/wiki1/files/*")
  end

  def test_file_upload_form
    get :file, :web => 'wiki1', :id => 'new_file.txt'
    assert_success
    assert_rendered_file 'file/file'
  end

  def test_file_download_text_file
    @web.wiki_files.create(:file_name => 'foo.txt', :description => 'Text file', 
        :content => "Contents of the file")

    r = get :file, :web => 'wiki1', :id => 'foo.txt'
    
    assert_success(bypass_body_parsing = true)
    assert_equal "Contents of the file", r.body
    assert_equal 'text/plain', r.headers['Content-Type']
  end

  def test_file_download_pdf_file
    @web.wiki_files.create(:file_name => 'foo.pdf', :description => 'PDF file', 
        :content => "aaa\nbbb\n")
  
    r = get :file, :web => 'wiki1', :id => 'foo.pdf'
    
    assert_success(bypass_body_parsing = true)
    assert_equal "aaa\nbbb\n", r.body
    assert_equal 'application/pdf', r.headers['Content-Type']
  end

  def test_pic_download_gif
    pic = File.open("#{RAILS_ROOT}/test/fixtures/rails.gif", 'rb') { |f| f.read }
    @web.wiki_files.create(:file_name => 'rails.gif', :description => 'An image', :content => pic)
    
    r = get :file, :web => 'wiki1', :id => 'rails.gif'
    
    assert_success(bypass_body_parsing = true)
    assert_equal 'image/gif', r.headers['Content-Type']
    assert_equal pic.size, r.body.size
    assert_equal pic, r.body
  end
  
#  def test_pic_unknown_pic
#    r = process 'pic', 'web' => 'wiki1', 'id' => 'non-existant.gif'
#    
#    assert_success
#    assert_rendered_file 'file/file'
#  end
#
#  def test_pic_upload_end_to_end
#    # edit and re-render home page so that it has an "unknown file" link to 'rails-e2e.gif'
#    @wiki.revise_page('wiki1', 'HomePage', '[[rails-e2e.gif:pic]]', Time.now, 'AnonymousBrave')
#    assert_equal "<p><span class=\"newWikiWord\">rails-e2e.gif<a href=\"../pic/rails-e2e.gif\">" +
#        "?</a></span></p>", 
#        @home.display_content
#  
#    # rails-e2e.gif is unknown to the system, so pic action goes to the file [upload] form
#    r = process 'pic', 'web' => 'wiki1', 'id' => 'rails-e2e.gif'
#    assert_success
#    assert_rendered_file 'file/file'
#
#    # User uploads the picture
#    picture = File.read("#{RAILS_ROOT}/test/fixtures/rails.gif")
#    r = process 'pic', 'web' => 'wiki1', 'id' => 'rails-e2e.gif', 'file' => StringIO.new(picture)
#    assert_redirect_url '/'
#    assert @wiki.file_yard(@web).has_file?('rails-e2e.gif')
#    assert_equal(picture, File.read("#{RAILS_ROOT}/storage/test/wiki1/rails-e2e.gif"))
#    
#    # this should refresh the page display content (cached)
#    assert_equal "<p><img alt=\"rails-e2e.gif\" src=\"../pic/rails-e2e.gif\" /></p>", 
#        @home.display_content
#  end
#
#  def test_pic_upload_end_to_end
#    # edit and re-render home page so that it has an "unknown file" link to 'rails-e2e.gif'
#    @wiki.revise_page('wiki1', 'HomePage', '[[instiki-e2e.txt:file]]', Time.now, 'AnonymousBrave',
#        test_renderer)
#    assert_equal "<p><span class=\"newWikiWord\">instiki-e2e.txt" +
#        "<a href=\"../file/instiki-e2e.txt\">?</a></span></p>", 
#        test_renderer(@home.revisions.last).display_content
#
#    # rails-e2e.gif is unknown to the system, so pic action goes to the file [upload] form
#    r = process 'file', 'web' => 'wiki1', 'id' => 'instiki-e2e.txt'
#    assert_success
#    assert_rendered_file 'file/file'
#
#    # User uploads the picture
#    file = "abcdefgh\n123"
#    r = process 'file', 'web' => 'wiki1', 'id' => 'instiki-e2e.txt', 'file' => StringIO.new(file)
#    assert_redirected_to :controller => 'wiki', :action => 'show', :web => 'wiki1', :id => 'HomePage'
#    assert @wiki.file_yard(@web).has_file?('instiki-e2e.txt')
#    assert_equal(file, File.read("#{RAILS_ROOT}/storage/test/wiki1/instiki-e2e.txt"))
#    
#    # this should refresh the page display content (cached)
#    @home = Page.find(@home.id)
#    assert_equal "<p><a class=\"existingWikiWord\" href=\"../file/instiki-e2e.txt\">" +
#        "instiki-e2e.txt</a></p>", 
#        test_renderer(@home.revisions.last).display_content
#  end
#
#  def test_uploads_blocking
#    set_web_property :allow_uploads, true
#    process 'file', 'web' => 'wiki1', 'id' => 'filename'
#    assert_success
#
#    set_web_property :allow_uploads, false
#    process 'file', 'web' => 'wiki1', 'id' => 'filename'
#    assert_response 403
#  end

end
