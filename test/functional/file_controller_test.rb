#!/bin/env ruby -w 

require File.dirname(__FILE__) + '/../test_helper'
require 'file_controller'

# Raise errors beyond the default web-based presentation
class FileController; def rescue_action(e) logger.error(e); raise e end; end

class FileControllerTest < Test::Unit::TestCase

  def setup
    setup_test_wiki
    setup_controller_test
  end

  def tear_down
    tear_down_wiki
  end

  def test_file
    process 'file', 'id' => 'foo.tgz'
  end

end
