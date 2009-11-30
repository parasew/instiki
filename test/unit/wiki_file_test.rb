require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require 'fileutils'

class WikiFileTest < ActiveSupport::TestCase
  include FileUtils
  fixtures :webs, :pages, :revisions, :system, :wiki_references

  def setup
    @web = webs(:test_wiki)
    mkdir_p("#{RAILS_ROOT}/webs/wiki1/files/")
    rm_rf("#{RAILS_ROOT}/webs/wiki1/files/*")
    WikiFile.delete_all
  end

  def test_basic_store_and_retrieve_ascii_file
    @web.wiki_files.create(:file_name => 'binary_file', :description => 'Binary file', :content => "\001\002\003")
    binary = WikiFile.find_by_file_name('binary_file')
    assert_equal "\001\002\003", binary.content
  end

  def test_basic_store_and_retrieve_binary_file
    @web.wiki_files.create(:file_name => 'text_file', :description => 'Text file', :content => "abc")
    text = WikiFile.find_by_file_name('text_file')
    assert_equal "abc", text.content
  end

  def test_storing_an_image
    rails_gif = File.open("#{RAILS_ROOT}/test/fixtures/rails.gif", 'rb') { |f| f.read }
    assert_equal rails_gif.size, File.size("#{RAILS_ROOT}/test/fixtures/rails.gif")

    @web.wiki_files.create(:file_name => 'rails.gif', :description => 'Rails logo', :content => rails_gif)

    rails_gif_from_db = WikiFile.find_by_file_name('rails.gif')
    assert_equal rails_gif.size, rails_gif_from_db.content.size
    assert_equal rails_gif, rails_gif_from_db.content
  end
  
  def test_mandatory_fields_validations
    assert_validation(:file_name, '', :fail)
    assert_validation(:file_name, nil, :fail)
    assert_validation(:content, '', :fail)
    assert_validation(:content, nil, :fail)
  end
  
  def test_upload_size_validation
    assert_validation(:content, 'a' * 100.kilobytes, :pass)
    assert_validation(:content, 'a' * (100.kilobytes + 1), :fail)
  end
  
  def test_file_name_size_validation
    assert_validation(:file_name, '', :fail)
    assert_validation(:file_name, 'a', :pass)
    assert_validation(:file_name, 'a' * 50, :pass)
    assert_validation(:file_name, 'a' * 51, :fail)
  end
  
  def test_file_name_pattern_validation
    assert_validation(:file_name, ".. Accep-table File.name", :pass)
    assert_validation(:file_name, "/bad", :fail)
    assert_validation(:file_name, "~bad", :fail)
    assert_validation(:file_name, "..\bad", :fail)
    assert_validation(:file_name, "\001bad", :fail)
    assert_validation(:file_name, ".", :fail)
    assert_validation(:file_name, "..", :fail)
  end

  def test_find_by_file_name
    assert_equal @file1, WikiFile.find_by_file_name('file1.txt')
    assert_nil WikiFile.find_by_file_name('unknown_file')
  end

  def assert_validation(field, value, expected_result)
    values = {:file_name => '0', :description => '0', :content =>  '0'}
    raise "WikiFile has no attribute named #{field.inspect}" unless values.has_key?(field)
    values[field] = value

    new_object = @web.wiki_files.create(values)
    if expected_result == :pass then assert(new_object.valid?, new_object.errors.inspect)
    elsif expected_result == :fail then assert(!new_object.valid?)
    else raise "Unknown value of expected_result: #{expected_result.inspect}"
    end
  end

end
