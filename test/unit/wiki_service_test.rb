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

    assert_doesnt_change_state_or_log :authenticate, 'pswd'
    assert_doesnt_change_state_or_log :read_page, 'instiki', 'TestReadOnlyOperations'
    assert_doesnt_change_state_or_log :setup?
    assert_doesnt_change_state_or_log :webs
    
    @s.write_page 'instiki', 'FirstPage', "Electric shocks, I love 'em", 
        Time.now, 'DavidHeinemeierHansson'
    assert_equal "Electric shocks, I love 'em", @s.read_page('instiki', 'FirstPage').content
  end

  def test_aborted_transaction
    @s.write_page 'instiki', 'FirstPage', "Electric shocks, I love 'em", 
        10.minutes.ago, 'DavidHeinemeierHansson'

    assert_doesnt_change_state('revise_page with unchanged content') {
      begin
        @s.revise_page 'instiki', 'FirstPage', "Electric shocks, I love 'em", 
            Time.now, 'DavidHeinemeierHansson'
        fail 'Expected Instiki::ValidationError not raised'
      rescue Instiki::ValidationError
      end
    }
  end


  # Checks that a method call or a block doesn;t change the persisted state of the wiki
  # Usage:
  #   assert_doesnt_change_state :read_page, 'instiki', 'TestReadOnlyOperations'
  # or
  #   assert_doesnt_change_state {|wiki| wiki.webs}

  def assert_doesnt_change_state(method, *args, &block)
    _assert_doesnt_change_state(including_command_log = false, method, *args, &block)
  end
  
  # Same as assert_doesnt_change_state, but also asserts that no vommand log is generated
  def assert_doesnt_change_state_or_log(method, *args, &block)
    _assert_doesnt_change_state(including_command_log = true, method, *args, &block)
  end

  private

  def _assert_doesnt_change_state(including_log, method, *args)
    WikiService.snapshot
    last_snapshot_before = last_snapshot

    if block_given?
      yield @s
    else
      @s.send(method, *args)
    end

    if including_log
      command_logs = Dir[RAILS_ROOT + 'storage/test/*.command_log']
      assert command_logs.empty?, "Calls to #{method} should not be logged"
    end

    last_snapshot_after = last_snapshot
    assert last_snapshot_before == last_snapshot_after,
        'Calls to #{method} should not change the state of any persisted object' 
  end

  def last_snapshot
    snapshots = Dir[RAILS_ROOT + '/storage/test/*.snapshot']
    assert !snapshots.empty?, "No snapshots found at #{RAILS_ROOT}/storage/test/"
    File.read(snapshots.last)
  end

end
