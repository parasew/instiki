require_relative '../test_helper'

# Integration test that exercises the full browser-to-controller upload path
# (routing, multipart parsing, the form's actual fields and action URL),
# unlike test_pic_upload_end_to_end which calls the file action directly.
class FileUploadTest < ActionDispatch::IntegrationTest
  fixtures :webs, :pages, :revisions, :system

  def setup
    @web = webs(:test_wiki)
    @web.update_attribute(:allow_uploads, true)
    WikiFile.delete_all
    require 'fileutils'
    FileUtils.rm_rf(Rails.root.join("webs", "wiki1"))
  end

  def test_upload_via_form_post_writes_file_to_disk
    # Simulate the full browser flow: GET the upload form, then POST to its
    # action URL with multipart form-data.
    get "/wiki1/files/rails-e2e.gif", headers: {'HTTP_REFERER' => 'javascript:alert("foo")'}
    assert_response :success
    assert_match(/<a>back<\/a>/, response.body)
    get "/wiki1/files/rails-e2e.gif", headers: {'HTTP_REFERER' => 'http://example.com'}
    assert_response :success
    assert_match(/<a href='http:\/\/example.com'>back<\/a>/, response.body)

    # Parse the rendered form to find its action URL.
    require 'nokogiri'
    doc = Nokogiri::HTML(response.body)
    upload_form = doc.css("form[enctype='multipart/form-data']").first
    refute_nil upload_form, "expected an upload form with multipart enctype"
    action_url = upload_form["action"]

    # Now POST to that URL with multipart data, the way a browser would.
    post action_url, params: {
      :referring_page => "/wiki1/show/Oak",
      :file => {
        :file_name => "rails-e2e.gif",
        :content => fixture_file_upload("rails.gif", "image/gif"),
        :description => "Rails, end-to-end"
      }
    }

    assert_response :redirect, "expected a redirect after a valid upload, got #{response.status}: #{response.body[0..400]}"
    assert_redirected_to "/wiki1/show/Oak"

    on_disk = Rails.root.join("webs", "wiki1", "files", "rails-e2e.gif")
    assert File.exist?(on_disk), "expected uploaded file at #{on_disk}"
    expected = File.binread(Rails.root.join("test", "fixtures", "rails.gif"))
    assert_equal expected.size, File.size(on_disk)
    assert_equal expected, File.binread(on_disk)
  end
end
