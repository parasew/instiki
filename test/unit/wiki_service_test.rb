#!/bin/env ruby

require File.dirname(__FILE__) + '/../test_helper'
require 'wiki_service'

class WikiServiceTest < Test::Unit::TestCase
  def setup
    @s = WikiServiceWithNoPersistence.new
    @s.create_web 'Instiki', 'instiki'
  end

  def test_read_write_page
    @s.write_page 'instiki', 'FirstPage', "Electric shocks, I love 'em", 
        Time.now, 'DavidHeinemeierHansson'
    assert_equal "Electric shocks, I love 'em", @s.read_page('instiki', 'FirstPage').content
  end
end
