#!/bin/env ruby -w

require File.dirname(__FILE__) + '/../test_helper'
require 'fileutils'
require 'file_yard'
require 'stringio'

class FileYardTest < Test::Unit::TestCase

  def setup
    FileUtils.mkdir_p(file_path)
    FileUtils.rm(Dir["#{file_path}/*"])
    @yard = FileYard.new(file_path)
  end

  def test_files
    assert_equal [], @yard.files
    
    # FileYard gets the list of files from directory in the constructor
    @yard.upload_file('aaa', StringIO.new('file contents'))
    assert_equal ["#{file_path}/aaa"], Dir["#{file_path}/*"]
    assert_equal ['aaa'], @yard.files
    assert @yard.has_file?('aaa')
    assert_equal 'file contents', File.read(@yard.file_path('aaa'))
  end

  def test_file_path
    assert_equal "#{file_path}/abcd", @yard.file_path('abcd')
  end

  def file_path
    "#{RAILS_ROOT}/storage/test/instiki"
  end

end