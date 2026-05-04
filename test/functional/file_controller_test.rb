#!/usr/bin/env ruby

require Rails.root.join('test', 'test_helper')
require 'file_controller'
require 'fileutils'
require 'stringio'

# Raise errors beyond the default web-based presentation
class FileController; def rescue_action(e) logger.error(e); raise e end; end

class FileControllerTest < ActionController::TestCase
  fixtures :webs, :pages, :revisions, :system

  def setup
    @web = webs(:test_wiki)
    @wiki = Wiki.new
    WikiFile.delete_all
    require 'fileutils'
    FileUtils.rm_rf("#{Rails.root}/webs/wiki1")
  end

  def test_file_upload_form
    get :file, :web => 'wiki1', :id => 'new_file.txt'
    assert_response(:success)
    assert_template 'file/file'
  end

  def test_file_download_text_file
    @web.wiki_files.create(:file_name => 'foo.txt', :description => 'Text file', 
        :content => "Contents of the file")

    r = get :file, :web => 'wiki1', :id => 'foo.txt'

    assert_response(:success, bypass_body_parsing = true)
    assert_equal "Contents of the file", r.body
    assert_equal 'text/plain', r.headers['Content-Type']
    assert_match Regexp.new(Regexp.escape('inline; filename="foo.txt"')), r.headers["Content-Disposition"]
  end

  def test_file_download_html_file
    @web.wiki_files.create(:file_name => 'foo.html', :description => 'Text file', 
        :content => "Contents of the file")

    r = get :file, :web => 'wiki1', :id => 'foo.html'

    assert_response(:success, bypass_body_parsing = true)
    assert_equal "Contents of the file", r.body
    assert_equal 'application/octet-stream', r.headers['Content-Type']
    assert_match Regexp.new(Regexp.escape('attachment; filename="foo.html"')), r.headers["Content-Disposition"]
  end

  def test_file_download_pdf_file
    @web.wiki_files.create(:file_name => 'foo.pdf', :description => 'PDF file', 
        :content => "aaa\nbbb\n")

    r = get :file, :web => 'wiki1', :id => 'foo.pdf'

    assert_response(:success, bypass_body_parsing = true)
    assert_equal "aaa\nbbb\n", r.body
    assert_equal 'application/pdf', r.headers['Content-Type']
  end

  def test_pic_download_gif
    pic = File.open("#{Rails.root}/test/fixtures/rails.gif", 'rb') { |f| f.read }
    @web.wiki_files.create(:file_name => 'rails.gif', :description => 'An image', :content => pic)

    r = get :file, :web => 'wiki1', :id => 'rails.gif'

    assert_response(:success, bypass_body_parsing = true)
    assert_equal 'image/gif', r.headers['Content-Type']
    assert_equal pic.size, r.body.size
    assert_equal pic, r.body
    assert_match Regexp.new(Regexp.escape('inline; filename="rails.gif"')), r.headers["Content-Disposition"]
  end

  def test_pic_download_gif_published_web
    @web.update_attribute(:published, true)
    @web.update_attribute(:password, 'pswd')
    pic = File.open("#{Rails.root}/test/fixtures/rails.gif", 'rb') { |f| f.read }
    @web.wiki_files.create(:file_name => 'rails.gif', :description => 'An image', :content => pic)

    r = get :file, :web => 'wiki1', :id => 'rails.gif'

    assert_response(:success, bypass_body_parsing = true)
    assert_equal 'image/gif', r.headers['Content-Type']
    assert_equal pic.size, r.body.size
    assert_equal pic, r.body
    assert_match Regexp.new(Regexp.escape('inline; filename="rails.gif"')), r.headers["Content-Disposition"]
  end

  def test_pic_download_gif_unpublished_web
    @web.update_attribute(:published, false)
    @web.update_attribute(:password, 'pswd')
    pic = File.open("#{Rails.root}/test/fixtures/rails.gif", 'rb') { |f| f.read }
    @web.wiki_files.create(:file_name => 'rails.gif', :description => 'An image', :content => pic)
    get :file, :web => 'wiki1', :id => 'rails.gif'

    assert_response(:forbidden)
  end

  def test_pic_x_sendfile
    pic = File.open("#{Rails.root}/test/fixtures/rails.gif", 'rb') { |f| f.read }
    @web.wiki_files.create(:file_name => 'rails.gif', :description => 'An image', :content => pic)
    @request.env.update({ 'HTTP_X_SENDFILE_TYPE' => 'foo' })
    @request.remote_addr = '127.0.0.1'
    r = get :file, :web => 'wiki1', :id => 'rails.gif'

    assert_response(:success, bypass_body_parsing = true)
# It's no longer possible to use X-Sendfile in development; ergo no way to test
#    assert_match  '/rails.gif', r.headers['X-Sendfile']
    assert_equal 'image/gif', r.headers['Content-Type']
    assert_match Regexp.new(Regexp.escape('inline; filename="rails.gif"')), r.headers["Content-Disposition"]
  end

  def test_pic_x_sendfile_published_web
    @web.update_attribute(:published, true)
    @web.update_attribute(:password, 'pswd')
    pic = File.open("#{Rails.root}/test/fixtures/rails.gif", 'rb') { |f| f.read }
    @web.wiki_files.create(:file_name => 'rails.gif', :description => 'An image', :content => pic)
    @request.env.update({ 'HTTP_X_SENDFILE_TYPE' => 'foo' })
    @request.remote_addr = '127.0.0.1'
    r = get :file, :web => 'wiki1', :id => 'rails.gif'

    assert_response(:success, bypass_body_parsing = true)
# It's no longer possible to use X-Sendfile in development; ergo no way to test
#    assert_match  '/rails.gif', r.headers['X-Sendfile']
    assert_equal 'image/gif', r.headers['Content-Type']
    assert_match Regexp.new(Regexp.escape('inline; filename="rails.gif"')), r.headers["Content-Disposition"]
  end

  def test_pic_x_sendfile_unpublished_web
    @web.update_attribute(:published, false)
    @web.update_attribute(:password, 'pswd')
    pic = File.open("#{Rails.root}/test/fixtures/rails.gif", 'rb') { |f| f.read }
    @web.wiki_files.create(:file_name => 'rails.gif', :description => 'An image', :content => pic)
    @request.env.update({ 'HTTP_X_SENDFILE_TYPE' => 'foo' })
    @request.remote_addr = '127.0.0.1'
    get :file, :web => 'wiki1', :id => 'rails.gif'

    assert_response(:forbidden)
  end

  def test_pic_x_sendfile_type_nonlocal
    pic = File.open("#{Rails.root}/test/fixtures/rails.gif", 'rb') { |f| f.read }
    @web.wiki_files.create(:file_name => 'rails.gif', :description => 'An image', :content => pic)
    @request.env.update({ 'HTTP_X_SENDFILE_TYPE' => 'foo' })
    r = get :file, :web => 'wiki1', :id => 'rails.gif'

    assert_response(:success, bypass_body_parsing = true)
    assert_equal 'image/gif', r.headers['Content-Type']
    assert_equal pic.size, r.body.size
    assert_equal pic, r.body
    assert_match Regexp.new(Regexp.escape('inline; filename="rails.gif"')), r.headers["Content-Disposition"]
  end

  def test_pic_unknown_pic
    get :file, :web => 'wiki1', :id => 'non-existant.gif'

    assert_response(:success)
    assert_template 'file/file'
  end

  def test_pic_upload_published_web
    @web.update_attribute(:published, true)
    @web.update_attribute(:password, 'pswd')
    @web.update_attribute(:allow_uploads, true)
    # edit and re-render a page so that it has an "unknown file" link to 'rails-e2e.gif'
    PageRenderer.setup_url_generator(StubUrlGenerator.new)
    renderer = PageRenderer.new
    @wiki.revise_page('wiki1', 'Oak', 'Oak', '[[rails-e2e.gif:pic]]', 
        Time.now, 'AnonymousBrave', renderer)
    assert_equal "<p><span class='newWikiWord'>rails-e2e.gif</span></p>",
        renderer.display_published

    # rails-e2e.gif is unknown to the system, so pic action goes to the file [upload] form
    get :file, :web => 'wiki1', :id => 'rails-e2e.gif'
    assert_response(:forbidden)
  end

  def test_pic_upload_unpublished_web
    @web.update_attribute(:published, false)
    @web.update_attribute(:password, 'pswd')
    @web.update_attribute(:allow_uploads, true)
    # edit and re-render a page so that it has an "unknown file" link to 'rails-e2e.gif'
    PageRenderer.setup_url_generator(StubUrlGenerator.new)
    renderer = PageRenderer.new
    @wiki.revise_page('wiki1', 'Oak', 'Oak', '[[rails-e2e.gif:pic]]', 
        Time.now, 'AnonymousBrave', renderer)
    assert_equal "<p><span class='newWikiWord'>rails-e2e.gif</span></p>",
        renderer.display_published

    # rails-e2e.gif is unknown to the system, so pic action goes to the file [upload] form
    get :file, :web => 'wiki1', :id => 'rails-e2e.gif'
    assert_response(:forbidden)
  end

  def test_pic_upload_end_to_end
    # edit and re-render a page so that it has an "unknown file" link to 'rails-e2e.gif'
    PageRenderer.setup_url_generator(StubUrlGenerator.new)
    renderer = PageRenderer.new
    @wiki.revise_page('wiki1', 'Oak', 'Oak', '[[rails-e2e.gif:pic]]', 
        Time.now, 'AnonymousBrave', renderer)
    assert_equal "<p><span class='newWikiWord'>rails-e2e.gif<a href='../file/rails-e2e.gif'>" +
        "?</a></span></p>",
        renderer.display_content

    # rails-e2e.gif is unknown to the system, so pic action goes to the file [upload] form
    get :file, :web => 'wiki1', :id => 'rails-e2e.gif'
    assert_response(:success)
    assert_template 'file/file'

    # User uploads the picture
    picture = File.read("#{Rails.root}/test/fixtures/rails.gif", encoding: 'ascii-8bit')
    # POST upload through the controller's `params['file']` form-submit branch.
    # Wrap the gif in a Rack::Test::UploadedFile (what fixture_file_upload
    # returns) so the controller-test framework preserves the binary content
    # — a bare StringIO gets serialized via its inspect string in Rails 5+.
    r = post :file, params: {
              :web => 'wiki1', :id => 'rails-e2e.gif',
              :referring_page => '/wiki1/show/Oak',
              :file => {:file_name => 'rails-e2e.gif',
                        :content => fixture_file_upload('rails.gif', 'image/gif'),
                        :description => 'Rails, end-to-end'}}
    assert_redirected_to  '/wiki1/show/Oak'
    assert @web.has_file?('rails-e2e.gif')
    assert_equal(picture, WikiFile.find_by_file_name('rails-e2e.gif').content)
    # And — the file should actually be written to webs/wiki1/files/ — the
    # in-memory record + DB row aren't enough; the on-disk copy is what
    # subsequent <img>-tag requests actually serve.
    on_disk = File.join(Rails.root, "webs", "wiki1", "files", "rails-e2e.gif")
    assert File.exist?(on_disk), "Expected uploaded file on disk at #{on_disk}"
    assert_equal picture.size, File.size(on_disk)
    assert_equal picture, File.binread(on_disk)
    PageRenderer.setup_url_generator(StubUrlGenerator.new)
    @wiki.revise_page('wiki1', 'Oak', 'Oak', 'Try [[rails-e2e.gif:pic]] again.',
        Time.now, 'AnonymousBrave', renderer)
    assert_equal "<p>Try <img alt='Rails, end-to-end' src='../file/rails-e2e.gif'/> again.</p>",
        renderer.display_content
    assert_equal "<p>Try <img alt='Rails, end-to-end' src='../file/rails-e2e.gif'/> again.</p>",
        renderer.display_published
  end

  def test_import
    # POST is required for file uploads in Rails 5+; the original Rails-2 test
    # used GET to bypass form-spam-protection but Rails 6 url-encodes params for
    # GET, turning the uploaded file object into its inspect string.
    post :import, params: {
          :web => 'wiki1',
          :file => fixture_file_upload('exported_markup.zip', 'application/zip')}
    assert_response(:redirect)
    assert @web.has_page?('ImportedPage')
  end

  def uploaded_file(path, content_type="application/octet-stream", filename=nil)
    filename ||= File.basename(path)
    t = Tempfile.new(filename)
    FileUtils.copy_file(path, t.path)
    (class << t; self; end;).class_eval do
      alias local_path path
      define_method(:original_filename) { filename }
      define_method(:content_type) { content_type }
    end
    return t
  end

end
