#!/bin/env ruby

require File.dirname(__FILE__) + '/../test_helper'
require 'wiki_service'
require 'fileutils'

class WikiServiceTest < Test::Unit::TestCase

  # Clean the test storage directory before the run
  unless defined? @@storage_cleaned
    FileUtils.rm(Dir[RAILS_ROOT + 'storage/test/*.command_log'])
    FileUtils.rm(Dir[RAILS_ROOT + 'storage/test/*.snapshot'])
    FileUtils.rm(Dir[RAILS_ROOT + 'storage/test/*.tex'])
    FileUtils.rm(Dir[RAILS_ROOT + 'storage/test/*.zip'])
    FileUtils.rm(Dir[RAILS_ROOT + 'storage/test/*.pdf'])
    @@cleaned_storage = true
  end

  def setup
    @s = WikiService.instance
    @s.create_web 'Instiki', 'instiki'
  end

  def teardown
    @s.delete_web 'instiki'
  end

  def test_read_write_page
    @s.write_page 'instiki', 'FirstPage', "Electric shocks, I love 'em", 
        Time.now, 'DavidHeinemeierHansson'
    assert_equal "Electric shocks, I love 'em", @s.read_page('instiki', 'FirstPage').content
  end
end
