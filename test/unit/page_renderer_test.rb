require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class PageRendererTest < Test::Unit::TestCase
  fixtures :webs, :pages, :revisions, :system, :wiki_references
  
  def setup
    @wiki = Wiki.new
    @web = webs(:test_wiki)
    @page = pages(:home_page)
    @revision = revisions(:home_page_second_revision)
  end
  
  def test_wiki_word_linking
    @web.add_page('SecondPage', 'Yo, yo. Have you EverBeenHated', 
                   Time.now, 'DavidHeinemeierHansson', test_renderer)
    
    assert_equal("<p>Yo, yo. Have you <span class='newWikiWord'>Ever Been Hated" + 
        "<a href='../show/EverBeenHated'>?</a></span></p>", 
        rendered_content(@web.page("SecondPage")))
    
    @web.add_page('EverBeenHated', 'Yo, yo. Have you EverBeenHated', Time.now, 
                  'DavidHeinemeierHansson', test_renderer)
    assert_equal("<p>Yo, yo. Have you <a class='existingWikiWord' " +
        "href='../show/EverBeenHated'>Ever Been Hated</a></p>", 
        rendered_content(@web.page("SecondPage")))
  end
  
  def test_wiki_words
    assert_equal %w( HisWay MyWay SmartEngine SmartEngineGUI ThatWay ), 
        test_renderer(@revision).wiki_words.sort
    
    @wiki.write_page('wiki1', 'NoWikiWord', 'hey you!', Time.now, 'Me', test_renderer)
    assert_equal [], test_renderer(@wiki.read_page('wiki1', 'NoWikiWord').revisions.last).wiki_words
  end
  
  def test_existing_pages
    assert_equal %w( MyWay SmartEngine ThatWay ), test_renderer(@revision).existing_pages.sort
  end
  
  def test_unexisting_pages
    assert_equal %w( HisWay SmartEngineGUI ), test_renderer(@revision).unexisting_pages.sort
  end

  def test_content_with_wiki_links
    assert_equal "<p><span class='newWikiWord'>His Way<a href='../show/HisWay'>?</a></span> " +
        "would be <a class='existingWikiWord' href='../show/MyWay'>My Way</a> " +
        "<math class='maruku-mathml' display='inline' xmlns='http://www.w3.org/1998/Math/MathML'>" +
        "<mi>sin</mi><mo stretchy='false'>(</mo><mi>x</mi><mo stretchy='false'>)</mo><semantics>" +
        "<annotation-xml encoding='SVG1.1'><svg/></annotation-xml></semantics></math> in kinda " +
        "<a class='existingWikiWord' href='../show/ThatWay'>That Way</a> in " +
        "<span class='newWikiWord'>His Way<a href='../show/HisWay'>?</a></span> " +
        %{though <a class='existingWikiWord' href='../show/MyWay'>My Way</a> OverThere \342\200\223 see } +
        "<a class='existingWikiWord' href='../show/SmartEngine'>Smart Engine</a> in that " +
        "<span class='newWikiWord'>Smart Engine GUI" +
        "<a href='../show/SmartEngineGUI'>?</a></span></p>", 
        test_renderer(@revision).display_content
  end

  def test_markdown
    set_web_property :markup, :markdownMML
  
    assert_markup_parsed_as(
        %{<p>equation <math class='maruku-mathml' } +
        %{display='inline' xmlns='http://www.w3.org/1998/Math/MathML'>} +
        %{<mi>sin</mi><mo stretchy='false'>(</mo><mi>x</mi><mo stretchy='false'>)</mo></math></p>},
        "equation $\\sin(x)$")
  
    assert_markup_parsed_as(
        %{<h1 id='my_headline'>My Headline</h1>\n\n<p>that <span class='newWikiWord'>} +
        %{Smart Engine GUI<a href='../show/SmartEngineGUI'>?</a></span></p>}, 
        "My Headline\n===========\n\nthat SmartEngineGUI")
  
    assert_markup_parsed_as(
        %{<h1 id='my_headline'>My Headline</h1>\n\n<p>that <span class='newWikiWord'>} +
        %{Smart Engine GUI<a href='../show/SmartEngineGUI'>?</a></span></p>}, 
        "#My Headline#\n\nthat SmartEngineGUI")
  
    assert_markup_parsed_as(
        %{<p>SVG <animateColor title='MathML'><span class='newWikiWord'>} +
        %{Math ML<a href='../show/MathML'>?</a></span></animateColor></p>}, 
        "SVG <animateColor title='MathML'>MathML</animateColor>")
  
    assert_markup_parsed_as(
        %{<div class='maruku-equation'><math class='maruku-mathml' display='block' } +
        %{xmlns='http://www.w3.org/1998/Math/MathML'><mi>sin</mi><mo stretchy='false'>} +
        %{(</mo><mi>x</mi><mo stretchy='false'>)</mo><semantics><annotation-xml encoding='SVG1.1'>} +
        %{<svg/></annotation-xml></semantics></math><div class='maruku-eq-tex'><code style='display: none;'>} +
        %{\\sin(x) \\begin{svg}<svg/>\\end{svg}</code></div></div>},
        "$$\\sin(x) \\begin{svg}<svg/>\\end{svg}$$")
  
    code_block = [ 
      'This is a code block:',
        '',
        '    def a_method(arg)',
        '    return ThatWay',
        '',
        'Nice!'
      ].join("\n")
  
    assert_markup_parsed_as(
        %{<p>This is a code block:</p>\n\n<pre><code>def a_method(arg)\n} +
        %{return ThatWay</code></pre>\n\n<p>Nice!</p>}, 
        code_block)

    assert_markup_parsed_as(
        %{<p><math class='maruku-mathml' } +
        %{display='inline' xmlns='http://www.w3.org/1998/Math/MathML'>} +
        %{<mi>sin</mi><mo stretchy='false'>(</mo><mi>x</mi><mo stretchy='false'>)</mo></math> ecuasi\303\263n</p>},
        "$\\sin(x)$ ecuasi\303\263n")
   
    assert_markup_parsed_as(
        %{<p>ecuasi\303\263n</p>\n<div class='maruku-equation'><math class='maruku-mathml' } +
        %{display='block' xmlns='http://www.w3.org/1998/Math/MathML'><mi>sin</mi>} +
        %{<mo stretchy='false'>(</mo><mi>x</mi><mo stretchy='false'>)</mo></math>} +
        %{<div class='maruku-eq-tex'><code style='display: none;'>\\sin(x)</code></div></div>}, 
        "ecuasi\303\263n\n$$\\sin(x)$$")
  
    assert_markup_parsed_as(
        %{<p>ecuasi\303\263n</p>\n\n<p><math class='maruku-mathml' } +
        %{display='inline' xmlns='http://www.w3.org/1998/Math/MathML'>} +
        %{<mi>sin</mi><mo stretchy='false'>(</mo><mi>x</mi><mo stretchy='false'>)</mo></math></p>},
        "ecuasi\303\263n \n\n$\\sin(x)$")
  
    assert_markup_parsed_as(
        %{<p>ecuasi\303\263n <math class='maruku-mathml' } +
        %{display='inline' xmlns='http://www.w3.org/1998/Math/MathML'>} +
        %{<mi>sin</mi><mo stretchy='false'>(</mo><mi>x</mi><mo stretchy='false'>)</mo></math></p>},
        "ecuasi\303\263n $\\sin(x)$")
  
  end
  
  def test_markdown_hyperlink_with_slash
    # in response to a bug, see http://dev.instiki.org/attachment/ticket/177
    set_web_property :markup, :markdown
  
    assert_markup_parsed_as(
        "<p><a href='http://example/with/slash'>text</a></p>", 
        '[text](http://example/with/slash)')
  end
  
  def test_mixed_formatting
    textile_and_markdown = [
      'Markdown heading',
      '================',
      '',
      'h2. Textile heading',
      '',
      '*some* **text** _with_ -styles-',
      '',
      '* list 1',
      '* list 2'
    ].join("\n")
    
    set_web_property :markup, :markdown
    assert_markup_parsed_as(
      "<h1 id='markdown_heading'>Markdown heading</h1>\n\n" +
      "<p>h2. Textile heading</p>\n\n" +
      "<p><em>some</em> <strong>text</strong> <em>with</em> -styles-</p>\n\n" +
      "<ul>\n<li>list 1</li>\n\n<li>list 2</li>\n</ul>",
      textile_and_markdown)
    
    set_web_property :markup, :textile
    assert_markup_parsed_as(
      "<p>Markdown heading<br/>================</p>\n\n\n\t<h2>Textile heading</h2>" +
      "\n\n\n\t<p><strong>some</strong> <b>text</b> <em>with</em> <del>styles</del></p>" +
      "\n\n\n\t<ul>\n\t<li>list 1</li>\n\t\t<li>list 2</li>\n\t</ul>",
      textile_and_markdown)
    
    set_web_property :markup, :mixed
    assert_markup_parsed_as(
      "<h1>Markdown heading</h1>\n\n\n\t<h2>Textile heading</h2>\n\n\n\t" +
      "<p><strong>some</strong> <b>text</b> <em>with</em> <del>styles</del></p>\n\n\n\t" +
      "<ul>\n\t<li>list 1</li>\n\t\t<li>list 2</li>\n\t</ul>",
      textile_and_markdown)
  end
  
  def test_rdoc
    set_web_property :markup, :rdoc
  
    @revision = Revision.new(:page => @page, :content => '+hello+ that SmartEngineGUI', 
        :author => Author.new('DavidHeinemeierHansson'))
  
    assert_equal "<tt>hello</tt> that <span class='newWikiWord'>Smart Engine GUI" +
        "<a href='../show/SmartEngineGUI'>?</a></span>\n\n", 
        test_renderer(@revision).display_content
  end
  
#  def test_content_with_auto_links
#    assert_markup_parsed_as(
#        '<p><a href="http://www.loudthinking.com/">http://www.loudthinking.com/</a> ' +
#        'points to <a class="existingWikiWord" href="../show/ThatWay">That Way</a> from ' +
#        '<a href="mailto:david@loudthinking.com">david@loudthinking.com</a></p>', 
#        'http://www.loudthinking.com/ points to ThatWay from david@loudthinking.com')
#  
#  end  
  
  def test_content_with_aliased_links
    assert_markup_parsed_as(
        "<p>Would a <a class='existingWikiWord' href='../show/SmartEngine'>clever motor" +
	    '</a> go by any other name?</p>',
        'Would a [[SmartEngine|clever motor]] go by any other name?')
  end
  
  def test_content_with_wikiword_in_em
    assert_markup_parsed_as(
        "<p><em>should we go <a class='existingWikiWord' href='../show/ThatWay'>" +
	    "That Way</a> or <span class='newWikiWord'>This Way<a href='../show/ThisWay'>?</a>" +
	    '</span></em></p>', 
        '_should we go ThatWay or ThisWay _')
  end
  
  # wikiwords are invalid as styles, must be in "name: value" form
  def test_content_with_wikiword_in_style_tag
    assert_markup_parsed_as(
        "<p>That is some <em style=''>Stylish Emphasis</em></p>", 
	    "That is some <em style='WikiWord'>Stylish Emphasis</em>")
  end
 
  # validates format of style..
  def test_content_with_valid_style_in_style_tag
    assert_markup_parsed_as(
        "<p>That is some <em style='text-align: right;'>Stylish Emphasis</em></p>", 
	    "That is some <em style='text-align: right'>Stylish Emphasis</em>")
  end
  
  def test_content_with_escaped_wikiword
    # there should be no wiki link
    assert_markup_parsed_as('<p>WikiWord</p>', '\WikiWord')
  end
  
  def test_content_with_pre_blocks
    set_web_property :markup, :markdownMML
    assert_markup_parsed_as(
      "<p>A <code>class SmartEngine</code> would not mark up</p>\n\n<pre><code>CodeBlocks</code></pre>\n\n<p>would it?</p>", 
      "A `class SmartEngine` would not mark up\n\n    CodeBlocks\n\nwould it?")
    assert_markup_parsed_as(
      "<p>A <code>class SmartEngine</code> would not mark up</p>\n<pre>CodeBlocks</pre>\n<p>would it?</p>", 
      "A <code>class SmartEngine</code> would not mark up\n\n<pre>CodeBlocks</pre>\n\nwould it?")
  end
  
#  def test_content_with_autolink_in_parentheses
#    assert_markup_parsed_as(
#      '<p>The W3C body (<a href="http://www.w3c.org">' +
#      'http://www.w3c.org</a>) sets web standards</p>', 
#      'The W3C body (http://www.w3c.org) sets web standards')
#  end
  
  def test_content_with_link_in_parentheses
    assert_markup_parsed_as(
      "<p>(<a href='http://wiki.org/wiki.cgi?WhatIsWiki'>What is a wiki?</a>)</p>",
      '([What is a wiki?](http://wiki.org/wiki.cgi?WhatIsWiki))')
  end
  
  def test_content_with_image_link
    assert_markup_parsed_as( 
      "<p>This <img alt='' src='http://hobix.com/sample.jpg'/> is a Markdown image link.</p>", 
      'This ![](http://hobix.com/sample.jpg) is a Markdown image link.')
  end
  
  def test_content_with_inlined_img_tag
    assert_markup_parsed_as( 
      "<p>This <img alt='' src='http://hobix.com/sample.jpg'/> is an inline image link.</p>", 
      'This <img src="http://hobix.com/sample.jpg" alt="" /> is an inline image link.')
       
    # currently, upper case HTML elements are not allowed
    assert_markup_parsed_as( 
      "<p>This &lt;IMG SRC='http://hobix.com/sample.jpg' alt=''/&gt; is an inline image link.</p>", 
      'This <IMG SRC="http://hobix.com/sample.jpg" alt="" /> is an inline image link.')
  end
  
  def test_nowiki_tag
    assert_markup_parsed_as( 
      '<p>Do not mark up [[this text]] or http://www.thislink.com.</p>', 
      'Do not mark up <nowiki>[[this text]]</nowiki> ' +
      'or <nowiki>http://www.thislink.com</nowiki>.')
  end
  
  def test_malformed_nowiki
    assert_markup_parsed_as( 
      '<p><i><b/></i></p>', 
      '<nowiki><i><b></i></b></nowiki> ')
  end

  
  def test_multiline_nowiki_tag
    assert_markup_parsed_as( 
      "<p>Do not mark \n up [[this text]] \nand http://this.url.com  but markup " +
      "<span class='newWikiWord'>this<a href='../show/this'>?</a></span></p>",
      "Do not <nowiki>mark \n up [[this text]] \n" +
      "and http://this.url.com </nowiki> but markup [[this]]")
  end

  def test_markdown_nowiki_tag
    assert_markup_parsed_as( 
      '<p>Do not mark up *this text* or http://www.thislink.com.</p>', 
      'Do not mark up <nowiki>*this text*</nowiki> ' +
      'or <nowiki>http://www.thislink.com</nowiki>.')
  end
  
  def test_sanitize_nowiki_tag
    assert_markup_parsed_as(
      '<p>[[test]]&amp;<a href=\'a&amp;b\'>shebang</a> &lt;script&gt;alert("xss!");&lt;/script&gt; *foo*</p>',
      '<nowiki>[[test]]&<a href="a&b">shebang</a> <script>alert("xss!");</script> *foo*</nowiki>')
  end

  def test_entities
    assert_markup_parsed_as(
      "<p>Known: \342\210\256. Pass-through: &amp;. Unknown: &amp;foo;.</p>",
      "Known: &conint;. Pass-through: &amp;. Unknown: &foo;.")
  end
  
  def test_content_with_bracketted_wiki_word
    set_web_property :brackets_only, true
    assert_markup_parsed_as( 
      "<p>This is a WikiWord and a tricky name <span class='newWikiWord'>" +
      "Sperberg-McQueen<a href='../show/Sperberg-McQueen'>?</a></span>.</p>", 
      'This is a WikiWord and a tricky name [[Sperberg-McQueen]].')
  end
  
  def test_content_for_export
    assert_equal "<p><span class='newWikiWord'>His Way</span> would be " +
        "<a class='existingWikiWord' href='MyWay.html'>My Way</a> " +
        "<math class='maruku-mathml' display='inline' xmlns='http://www.w3.org/1998/Math/MathML'>" +
        "<mi>sin</mi><mo stretchy='false'>(</mo><mi>x</mi><mo stretchy='false'>)</mo><semantics>" +
        "<annotation-xml encoding='SVG1.1'><svg/></annotation-xml></semantics></math> in kinda " +
        "<a class='existingWikiWord' href='ThatWay.html'>That Way</a> in " +
        "<span class='newWikiWord'>His Way</span> though " +
        %{<a class='existingWikiWord' href='MyWay.html'>My Way</a> OverThere \342\200\223 see } +
        "<a class='existingWikiWord' href='SmartEngine.html'>Smart Engine</a> in that " +
        "<span class='newWikiWord'>Smart Engine GUI</span></p>", 
        test_renderer(@revision).display_content_for_export
  end
  
  def test_double_replacing
    @revision.content = "VersionHistory\r\n\r\ncry VersionHistory"
    assert_equal "<p><span class='newWikiWord'>Version History" +
        "<a href='../show/VersionHistory'>?</a></span></p>\n\n<p>cry " +
        "<span class='newWikiWord'>Version History<a href='../show/VersionHistory'>?</a>" +
        '</span></p>', 
        test_renderer(@revision).display_content
  
    @revision.content = "f\r\nVersionHistory\r\n\r\ncry VersionHistory"
    assert_equal "<p>f <span class='newWikiWord'>Version History" +
        "<a href='../show/VersionHistory'>?</a></span></p>\n\n<p>cry " +
        "<span class='newWikiWord'>Version History<a href='../show/VersionHistory'>?</a>" +
        "</span></p>", 
        test_renderer(@revision).display_content
  end  
  
  def test_difficult_wiki_words
    @revision.content = "[[It's just awesome GUI!]]"
    assert_equal "<p><span class='newWikiWord'>It's just awesome GUI!" +
        "<a href='../show/It%27s+just+awesome+GUI%21'>?</a></span></p>", 
        test_renderer(@revision).display_content
  end
  
  def test_revisions_diff
    Revision.create(:page => @page, :content => 'What a blue and lovely morning', 
        :author => Author.new('DavidHeinemeierHansson'), :revised_at => Time.now)
    Revision.create(:page => @page, :content => 'What a red and lovely morning today', 
        :author => Author.new('DavidHeinemeierHansson'), :revised_at => Time.now)

    assert_equal "<p><span> What a<del class='diffmod'> blue</del><ins class='diffmod'> red" +
        "</ins> and lovely morning<ins class='diffins'> today</ins></span></p>", test_renderer(@page.revisions.last).display_diff
  end
  
  def test_nowiki_sanitization
    assert_markup_parsed_as('<p>This sentence contains <span>a &amp; b</span> ' +
     '&lt;script&gt;alert("XSS!");&lt;/script&gt;. Do not touch!</p>',
      'This sentence contains <nowiki><span>a & b</span> <script>alert("XSS!");' +
      '</script></nowiki>. Do not touch!')
  end
  
  def test_link_to_file
    assert_markup_parsed_as( 
      "<p><span class='newWikiWord'>doc.pdf<a href='../file/doc.pdf'>?</a></span></p>",
      '[[doc.pdf:file]]')
  end
  
  def test_link_to_pic_and_file
    WikiFile.delete_all
    require 'fileutils'
    FileUtils.rm_rf("#{RAILS_ROOT}/public/wiki1/files/*")
    @web.wiki_files.create(:file_name => 'square.jpg', :description => 'Square', :content => 'never mind')
    assert_markup_parsed_as(
      "<p><img alt='Blue Square' src='../file/square.jpg'/></p>",
      '[[square.jpg|Blue Square:pic]]')
    assert_markup_parsed_as( 
      "<p><img alt='Square' src='../file/square.jpg'/></p>",
      '[[square.jpg:pic]]')
    assert_markup_parsed_as(
      "<p><a class='existingWikiWord' href='../file/square.jpg' title='Square'>Blue Square</a></p>",
      '[[square.jpg|Blue Square:file]]')
    assert_markup_parsed_as( 
      "<p><a class='existingWikiWord' href='../file/square.jpg' title='Square'>Square</a></p>",
      '[[square.jpg:file]]')
  end
  
  def test_link_to_pic_and_file_null_desc
    WikiFile.delete_all
    require 'fileutils'
    FileUtils.rm_rf("#{RAILS_ROOT}/public/wiki1/files/*")
    @web.wiki_files.create(:file_name => 'square.jpg', :description => '', :content => 'never mind')
    assert_markup_parsed_as(
      "<p><img alt='Blue Square' src='../file/square.jpg'/></p>",
      '[[square.jpg|Blue Square:pic]]')
    assert_markup_parsed_as( 
      "<p><img alt='' src='../file/square.jpg'/></p>",
      '[[square.jpg:pic]]')
    assert_markup_parsed_as(
      "<p><a class='existingWikiWord' href='../file/square.jpg' title=''>Blue Square</a></p>",
      '[[square.jpg|Blue Square:file]]')
    assert_markup_parsed_as( 
      "<p><a class='existingWikiWord' href='../file/square.jpg' title=''></a></p>",
      '[[square.jpg:file]]')
  end
  
  def test_link_to_non_existant_pic
  	assert_markup_parsed_as(
  	    "<p><span class='newWikiWord'>NonExistant<a href='../file/NonExistant.jpg'>?</a>" +
  	    '</span></p>',
        '[[NonExistant.jpg|NonExistant:pic]]')
  	assert_markup_parsed_as(
  	    "<p><span class='newWikiWord'>NonExistant.jpg<a href='../file/NonExistant.jpg'>?</a>" +
  	    '</span></p>',
        '[[NonExistant.jpg:pic]]')
  end
  
  def test_wiki_link_with_colon
  	assert_markup_parsed_as(
  	  "<p><span class='newWikiWord'>Instiki:Colon<a href='../../instiki/show/Colon'>?</a></span></p>",
  	  '[[Instiki:Colon]]')
  end
  
  def test_list_with_tildas
    list_with_tildas = <<-EOL
* [a](~b)
* c~ d
    EOL
  
    assert_markup_parsed_as(
        "<ul>\n<li><a href='~b'>a</a></li>\n\n<li>c~ d</li>\n</ul>",
        list_with_tildas)
  end
  
  def test_textile_image_in_mixed_wiki
    set_web_property :markup, :mixed
    assert_markup_parsed_as(
      "<p><img alt='' src='http://google.com'/>\nss</p>",
      "!http://google.com!\r\nss")
  end

  
  def test_references_creation_links
    new_page = @web.add_page('NewPage', 'HomePage NewPage', 
        Time.local(2004, 4, 4, 16, 50), 'AlexeyVerkhovsky', test_renderer)
        
    references = new_page.wiki_references(true)
    assert_equal 2, references.size
    assert_equal 'HomePage', references[0].referenced_name
    assert_equal WikiReference::LINKED_PAGE, references[0].link_type
    assert_equal 'NewPage', references[1].referenced_name
    assert_equal WikiReference::LINKED_PAGE, references[1].link_type
  end

  def test_references_creation_includes
    new_page = @web.add_page('NewPage', '[[!include IncludedPage]]',
        Time.local(2004, 4, 4, 16, 50), 'AlexeyVerkhovsky', test_renderer)
        
    references = new_page.wiki_references(true)
    assert_equal 1, references.size
    assert_equal 'IncludedPage', references[0].referenced_name
    assert_equal WikiReference::INCLUDED_PAGE, references[0].link_type
  end

  def test_references_creation_categories
    new_page = @web.add_page('NewPage', "Foo\ncategory: NewPageCategory",
        Time.local(2004, 4, 4, 16, 50), 'AlexeyVerkhovsky', test_renderer)

    references = new_page.wiki_references(true)
    assert_equal 1, references.size
    assert_equal 'NewPageCategory', references[0].referenced_name
    assert_equal WikiReference::CATEGORY, references[0].link_type
  end

  def test_references_creation_sanitized_categories
    new_page = @web.add_page('NewPage', "Foo\ncategory: <script>alert('XSS');</script>",
        Time.local(2004, 4, 4, 16, 50), 'AlexeyVerkhovsky', test_renderer)

    references = new_page.wiki_references(true)
    assert_equal 1, references.size
    assert_equal "&lt;script&gt;alert(&#39;XSS&#39;);&lt;/script&gt;", references[0].referenced_name
    assert_equal WikiReference::CATEGORY, references[0].link_type
  end
  
  def test_rendering_included_page_under_different_modes
    included = @web.add_page('Included', 'link to HomePage', Time.now, 'AnAuthor', test_renderer)
    main = @web.add_page('Main', '[[!include Included]]', Time.now, 'AnAuthor', test_renderer)
    
    assert_equal "<p>link to <a class='existingWikiWord' href='../show/HomePage'>Home Page</a></p>", 
                 test_renderer(main).display_content
    assert_equal "<p>link to <a class='existingWikiWord' href='../published/HomePage'>Home Page</a></p>",
                 test_renderer(main).display_published
    assert_equal "<p>link to <a class='existingWikiWord' href='HomePage.html'>Home Page</a></p>", 
                 test_renderer(main).display_content_for_export
  end

  private

  def add_sample_pages
    @in_love = @web.add_page('EverBeenInLove', 'Who am I me', 
        Time.local(2004, 4, 4, 16, 50), 'DavidHeinemeierHansson', test_renderer)
    @hated = @web.add_page('EverBeenHated', 'I am me EverBeenHated', 
        Time.local(2004, 4, 4, 16, 51), 'DavidHeinemeierHansson', test_renderer)
  end

  def assert_markup_parsed_as(expected_output, input)
    revision = Revision.new(:page => @page, :content => input, :author => Author.new('AnAuthor'))
    assert_equal expected_output, test_renderer(revision).display_content, 'Rendering output not as expected'
  end

  def rendered_content(page)
    test_renderer(page.revisions.last).display_content
  end
  
end
