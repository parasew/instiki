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
    WikiService.instance.setup('pswd', 'Wiki', 'wiki')
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

  def test_read_only_operations
    @s.write_page 'instiki', 'TestReadOnlyOperations', 'Read only operations dont change the' +
        'state of any object, and therefore should not be logged by Madeleine!', 
        Time.now, 'AlexeyVerkhovsky'

    assert_doesnt_change_state :authenticate, 'pswd'
    assert_doesnt_change_state :read_page, 'instiki', 'TestReadOnlyOperations'
    assert_doesnt_change_state :setup?
    assert_doesnt_change_state :webs
    
    @s.write_page 'instiki', 'FirstPage', "Electric shocks, I love 'em", 
        Time.now, 'DavidHeinemeierHansson'
    assert_equal "Electric shocks, I love 'em", @s.read_page('instiki', 'FirstPage').content
  end


  def assert_doesnt_change_state(method, *args)
    WikiService.snapshot
    last_snapshot_before = File.read(Dir[RAILS_ROOT + 'storage/test/*.snapshot'].last)
    
    @s.send(method, *args)

    command_logs = Dir[RAILS_ROOT + 'storage/test/*.command_log']
    assert command_logs.empty?, "Calls to #{method} should not be logged"
    last_snapshot_after = File.read(Dir[RAILS_ROOT + 'storage/test/*.snapshot'].last)
    assert last_snapshot_before == last_snapshot_after, 
      'Calls to #{method} should not change the state of any persisted object' 
  end
end
