#!/bin/env ruby -w 

require File.dirname(__FILE__) + '/../test_helper'
require 'file_controller'
require 'fileutils'

# Raise errors beyond the default web-based presentation
class FileController; def rescue_action(e) logger.error(e); raise e end; end

class FileControllerTest < Test::Unit::TestCase

  FILE_AREA = RAILS_ROOT + '/storage/test/wiki1'
  FileUtils.mkdir_p(FILE_AREA) unless File.directory?(FILE_AREA)

  def setup
    setup_test_wiki
    setup_controller_test
  end

  def tear_down
    tear_down_wiki
  end

  def test_file
    process 'file', 'web' => 'wiki1', 'id' => 'foo.tgz'
    
    assert_success
    assert_rendered_file 'file/file'
  end

  def test_file_download_text_file
    File.open("#{FILE_AREA}/foo.txt", 'wb') { |f| f.write "aaa\nbbb\n" }
  
    r = process 'file', 'web' => 'wiki1', 'id' => 'foo.txt'
    
    assert_success
    assert_equal "aaa\nbbb\n", r.binary_content
    assert_equal 'text/plain', r.headers['Content-Type']
  end

  def test_file_download_pdf_file
    File.open("#{FILE_AREA}/foo.pdf", 'wb') { |f| f.write "aaa\nbbb\n" }
  
    r = process 'file', 'web' => 'wiki1', 'id' => 'foo.pdf'
    
    assert_success
    assert_equal "aaa\nbbb\n", r.binary_content
    assert_equal 'application/pdf', r.headers['Content-Type']
  end

  def test_pic_download_gif
    FileUtils.cp("#{RAILS_ROOT}/test/fixtures/rails.gif", FILE_AREA)
    
    r = process 'pic', 'web' => 'wiki1', 'id' => 'rails.gif'
    
    assert_success
    assert_equal File.size("#{FILE_AREA}/rails.gif"), r.binary_content.size
  end

end
