#!/bin/env ruby -w

require File.dirname(__FILE__) + '/../test_helper'
require 'fileutils'
require 'file_yard'
require 'stringio'

class FileYardTest < Test::Unit::TestCase

  def setup
    FileUtils.mkdir_p(file_path)
    FileUtils.rm(Dir["#{file_path}/*"])
    @yard = FileYard.new(file_path, 100)
  end

  def test_check_upload_size
    assert_nothing_raised { @yard.check_upload_size(100.kilobytes) }
    assert_raises(Instiki::ValidationError) { @yard.check_upload_size(100.kilobytes + 1) }
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

  def test_size_limit
    @yard = FileYard.new(file_path, 1)
    one_kylobyte_string = "a" * 1024

    # as StringIO
    assert_nothing_raised { 
      @yard.upload_file('acceptable_file', StringIO.new(one_kylobyte_string)) 
    }
    assert_raises(Instiki::ValidationError) { 
      @yard.upload_file('one_byte_too_long', StringIO.new(one_kylobyte_string + 'a')) 
    }

    # as Tempfile
    require 'tempfile'
    Tempfile.open('acceptable_file') { |f| f.write(one_kylobyte_string) } 
      assert_nothing_raised { 
        @yard.upload_file('acceptable_file', f) 
      }
    }
    Tempfile.open('one_byte_too_long') { |f| f.write(one_kylobyte_string + 'a')
      assert_nothing_raised { 
        @yard.upload_file('one_byte_too_long_2', f)
      }
    }
  end

  def file_path
    "#{RAILS_ROOT}/storage/test/instiki"
  end

end