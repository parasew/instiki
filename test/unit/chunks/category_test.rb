#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
require 'chunks/category'

class CategoryTest < Test::Unit::TestCase
  include ChunkMatch

  def test_single_category
	match(Category, 'category: test', :list => ['test'], :hidden => nil, :unmask_text => 
	"<div class=\"property\"> category: <a class=\"category_link\" href=\"/wiki1/list/test\">test</a></div>")
	match(Category, 'category :   chunk test   ', :list => ['chunk test'], :hidden => nil, :unmask_text => 
	"<div class=\"property\"> category: <a class=\"category_link\" href=\"/wiki1/list/chunk+test\">chunk test</a></div>")
	match(Category, ':category: test', :list => ['test'], :hidden => ':')
  end

  def test_no_category
	match(Category, 'category:  ', :list => [], :hidden => nil)
	match(Category, 'category :   chunk test  , ', :list => ['chunk test'], :hidden => nil)
	match(Category, ':category:', :list => [], :hidden => ':')
  end

  def test_multiple_categories
	match(Category, 'category: test, multiple', :list => ['test', 'multiple'], :hidden => nil)
	match(Category, 'category : chunk test , multi category,regression test case  ', 
		:list => ['chunk test','multi category','regression test case'], :hidden => nil
	)
  end

  def test_multiple_categories_sanitized
	match(Category, 'category: test, multiple,<span>a & b</span> <script>alert("XSS!");</script>', :list => ['test', 'multiple', '&lt;span&gt;a &amp; b&lt;/span&gt; &lt;script&gt;alert(&quot;XSS!&quot;);&lt;/script&gt;'], :hidden => nil)
	match(Category, 'category : chunk test , multi category,<span>a & b</span> <script>alert("XSS!");</script>', 
		:list => ['chunk test','multi category','&lt;span&gt;a &amp; b&lt;/span&gt; &lt;script&gt;alert(&quot;XSS!&quot;);&lt;/script&gt;'], :hidden => nil
	)
  end

  def test_multiple_categories_invalid_utf8
	match(Category, "category: test, multiple,\000egg", :list => ['test', 'multiple', 'egg'], :hidden => nil)
	match(Category, "category : chunk test , multi category,,e\000gg", :list => ['chunk test', 'multi category', 'egg'], :hidden => nil)
  end

end
