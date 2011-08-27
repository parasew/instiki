#!/usr/bin/env ruby
# encoding: UTF-8

require Rails.root.join('test', 'test_helper')

class PageRendererTest < ActiveSupport::TestCase
  fixtures :webs, :pages, :revisions, :system, :wiki_references
  
  def setup
    @wiki = Wiki.new
    @web = webs(:test_wiki)
    @page = pages(:home_page)
    @revision = revisions(:home_page_second_revision)
  end
  
  def test_wiki_word_linking
    @web.add_page('SecondPage', 'Yo, yo. Have you EverBeenHated', 
                   Time.now, 'DavidHeinemeierHansson', x_test_renderer)
    
    assert_equal("<p>Yo, yo. Have you <span class='newWikiWord'>Ever Been Hated" + 
        "<a href='../show/EverBeenHated'>?</a></span></p>", 
        rendered_content(@web.page("SecondPage")))
    
    @web.add_page('EverBeenHated', 'Yo, yo. Have you EverBeenHated', Time.now, 
                  'DavidHeinemeierHansson', x_test_renderer)
    assert_equal("<p>Yo, yo. Have you <a class='existingWikiWord' " +
        "href='../show/EverBeenHated'>Ever Been Hated</a></p>", 
        rendered_content(@web.page("SecondPage")))
  end
  
  def test_wiki_words
    assert_equal %w( HisWay MyWay SmartEngine SmartEngineGUI ThatWay ), 
        x_test_renderer(@revision).wiki_words.sort
    
    @wiki.write_page('wiki1', 'NoWikiWord', 'hey you!', Time.now, 'Me', x_test_renderer)
    assert_equal [], x_test_renderer(@wiki.read_page('wiki1', 'NoWikiWord').revisions.last).wiki_words
  end
  
  def test_existing_pages
    assert_equal %w( MyWay SmartEngine ThatWay ), x_test_renderer(@revision).existing_pages.sort
  end
  
  def test_unexisting_pages
    assert_equal %w( HisWay SmartEngineGUI ), x_test_renderer(@revision).unexisting_pages.sort
  end

  def test_wiki_links_after_empty
    assert_markup_parsed_as(%{<code></code>\n<p>This is a <span class='newWikiWord'>wikilink<a href=} +
      %{'../show/wikilink'>?</a></span>.</p>},
      "<code></code>\n\nThis is a [[wikilink]].")
  end

  def test_content_with_wiki_links
    assert_equal "<p><span class='newWikiWord'>His Way<a href='../show/HisWay'>?</a></span> " +
        "would be <a class='existingWikiWord' href='../show/MyWay'>My Way</a> " +
        "<math class='maruku-mathml' display='inline' xmlns='http://www.w3.org/1998/Math/MathML'>" +
        "<mi>sin</mi><mo stretchy='false'>(</mo><mi>x</mi><mo stretchy='false'>)</mo><semantics>" +
        "<annotation-xml encoding='SVG1.1'><svg></svg></annotation-xml></semantics></math> in kinda " +
        "<a class='existingWikiWord' href='../show/ThatWay'>That Way</a> in " +
        "<span class='newWikiWord'>His Way<a href='../show/HisWay'>?</a></span> " +
        %{though <a class='existingWikiWord' href='../show/MyWay'>My Way</a> OverThere \342\200\223 see } +
        "<a class='existingWikiWord' href='../show/SmartEngine'>Smart Engine</a> in that " +
        "<span class='newWikiWord'>Smart Engine GUI" +
        "<a href='../show/SmartEngineGUI'>?</a></span></p>", 
        x_test_renderer(@revision).display_content
  end

  def test_markdown
    set_web_property :markup, :markdownMML
  
    assert_markup_parsed_as(
        %{<p>equation <math class='maruku-mathml' } +
        %{display='inline' xmlns='http://www.w3.org/1998/Math/MathML'>} +
        %{<mi>sin</mi><mo stretchy='false'>(</mo><mi>x</mi><mo stretchy='false'>)</mo></math></p>},
        "equation $\\sin(x)$")
  
    re = Regexp.new('\\A<h1 id=\'my_headline_\\d{1,4}\'>My Headline</h1>\n\n<p>that <span class=\'newWikiWord\'>Smart Engine GUI<a href=\'../show/SmartEngineGUI\'>\?</a></span></p>\\Z')

    assert_match_markup_parsed_as(re, "My Headline\n===========\n\nthat SmartEngineGUI")
  
    assert_match_markup_parsed_as(re, "#My Headline#\n\nthat SmartEngineGUI")

    str1 = %{<div class='un_defn'>\n<h6 id='definition_\\d\{1,4\}'>Definition</h6>\n\n<p>Let <math} +
    %{ class='maruku-mathml' display='inline' xmlns='http://www.w3.org/1998/Math/MathML'><mi>H</mi>} +
    %{</math> be a subgroup of a group <math class='maruku-mathml' display='inline' xmlns='http://w} +
    %{ww.w3.org/1998/Math/MathML'><mi>G</mi></math>. A <em>left coset</em> of <math class='maruku-m} +
    %{athml' display='inline' xmlns='http://www.w3.org/1998/Math/MathML'><mi>H</mi></math> in <math} +
    %{ class='maruku-mathml' display='inline' xmlns='http://www.w3.org/1998/Math/MathML'><mi>G</mi>} +
    %{</math> is a subset of <math class='maruku-mathml' display='inline' xmlns='http://www.w3.org/} +
    %{1998/Math/MathML'><mi>G</mi></math> that is of the form <math class='maruku-mathml' display='} +
    %{inline' xmlns='http://www.w3.org/1998/Math/MathML'><mi>x</mi><mi>H</mi></math>, where <math} +
    %{ class='maruku-mathml' display='inline' xmlns='http://www.w3.org/1998/Math/MathML'><mi>x</mi>} +
    %{<mo>\342\210\210</mo><mi>G</mi></math> and <math class='maruku-mathml' display='inline' xmlns} +
    %{='http://www.w3.org/1998/Math/MathML'><mi>x</mi><mi>H</mi><mo>=</mo><mo stretchy='false'>\\\{<} +
    %{/mo><mi>x</mi><mi>h</mi><mo>:</mo><mi>h</mi><mo>\342\210\210</mo><mi>H</mi><mo stretchy='fals} +
    %{e'>\\\}</mo></math>.</p>\n\n<p>Similarly a <em>right coset</em> of <math class='maruku-mathml'} +
    %{ display='inline' xmlns='http://www.w3.org/1998/Math/MathML'><mi>H</mi></math> in <math class} +
    %{='maruku-mathml' display='inline' xmlns='http://www.w3.org/1998/Math/MathML'><mi>G</mi></math} +
    %{> is a subset of <math class='maruku-mathml' display='inline' xmlns='http://www.w3.org/1998/M} +
    %{ath/MathML'><mi>G</mi></math> that is of the form <math class='maruku-mathml' display='inline} +
    %{' xmlns='http://www.w3.org/1998/Math/MathML'><mi>H</mi><mi>x</mi></math>, where <math class='} +
    %{maruku-mathml' display='inline' xmlns='http://www.w3.org/1998/Math/MathML'><mi>H</mi><mi>x</m} +
    %{i><mo>=</mo><mo stretchy='false'>\\\{</mo><mi>h</mi><mi>x</mi><mo>:</mo><mi>h</mi><mo>\342\210\210} +
    %{</mo><mi>H</mi><mo stretchy='false'>\\\}</mo></math>.</p>\n</div>\n\n} +
    %{<div class='num_lemma' id='LeftCosetsDisjoint'>\n<h6 id='lemma_\\d\{1,4\}'>Lemma</h6>\n\n<p>} +
    %{Let <math class='maruku-mathml' display='inline' xmlns='http://www.w3.org/1998/Math/MathML'>} +
    %{<mi>H</mi></math> be a subgroup of a group <math class='maruku-mathml' display='inline' xmlns} +
    %{='http://www.w3.org/1998/Math/MathML'><mi>G</mi></math>, and let <math class='maruku-mathml'} +
    %{ display='inline' xmlns='http://www.w3.org/1998/Math/MathML'><mi>x</mi></math> and <math cla} +
    %{ss='maruku-mathml' display='inline' xmlns='http://www.w3.org/1998/Math/MathML'><mi>y</mi></ma} +
    %{th> be elements of <math class='maruku-mathml' display='inline' xmlns='http://www.w3.org/1998/} +
    %{Math/MathML'><mi>G</mi></math>. Suppose that <math class='maruku-mathml' display='inline' xmln} +
    %{s='http://www.w3.org/1998/Math/MathML'><mi>x</mi><mi>H</mi><mo>\342\210\251</mo><mi>y</mi><mi>} +
    %{H</mi></math> is non-empty. Then <math class='maruku-mathml' display='inline' xmlns='http://ww} +
    %{w.w3.org/1998/Math/MathML'><mi>x</mi><mi>H</mi><mo>=</mo><mi>y</mi><mi>H</mi></math>.</p>\n</d} +
    %{iv>\n\n<div class='proof'>\n<h6 id='proof_\\d\{1,4\}'>Proof</h6>\n\n<p>Let <math class='maruku-m} +
    %{athml' display='inline' xmlns='http://www.w3.org/1998/Math/MathML'><mi>z</mi></math> be some e} +
    %{lement of <math class='maruku-mathml' display='inline' xmlns='http://www.w3.org/1998/Math/Math} +
    %{ML'><mi>x</mi><mi>H</mi><mo>\342\210\251</mo><mi>y</mi><mi>H</mi></math>.</p>\n</div>\n\n} +
    %{<div class='num_lemma' id='SizeOfLeftCoset'>\n<h6 id='lemma_\\d\{1,4\}'>Lemma</h6>\n\n<p>} +
    %{Let <math class='maruku-mathml' display='inline' xmlns='http://www.w3.org/1998/Math/MathML'>} +
    %{<mi>H</mi></math> be a finite subgroup of a group <math class='maruku-mathml' display='inline' xmlns} +
    %{='http://www.w3.org/1998/Math/MathML'><mi>G</mi></math>.</p>\n</div>\n\n} +
    %{<div class='num_theorem' id='Lagrange'>\n<h6 id='theorem_\\d\{1,4\}'>Theorem</h6>\n\n<p><strong>\\(Lagrange\342\200\231s Theorem\\).</strong> Let <math class='maruku-mathml' display='inline' xmlns='http://www.w3.org/1998/Math/MathML'><mi>G</mi></math> be a finite group, and let <math class='maruku-mathml' display='inline' xmlns='http://www.w3.org/1998/Math/MathML'><mi>H</mi></math> be a subgroup of <math class='maruku-mathml' display='inline' xmlns='http://www.w3.org/1998/Math/MathML'><mi>G</mi></math>.</p>\n</div>}

    str2 = <<END_THM
+-- {: .un_defn}
###### Definition
Let $H$ be a subgroup of a group $G$.  A *left coset* of $H$ in $G$ is a subset of $G$ that is of the form $x H$, where $x \\in G$ and $x H = \\{ x h : h \\in H \\}$.

Similarly a *right coset* of $H$ in $G$ is a subset of $G$ that is of the form $H x$, where $H x = \\{ h x : h \\in H \\}$.
=--

+-- {: .num_lemma #LeftCosetsDisjoint}
###### Lemma
Let $H$ be a subgroup of a group $G$, and let $x$ and $y$ be
elements of $G$. Suppose that $x H \\cap y H$ is non-empty. Then $x H = y H$.
=--

+-- {: .proof}
###### Proof
Let $z$ be some element of $x H \\cap y H$.
=--

+-- {: .num_lemma #SizeOfLeftCoset}
###### Lemma
Let $H$ be a finite subgroup of a group $G$.
=--

+-- {: .num_theorem #Lagrange}
###### Theorem
**(Lagrange's Theorem).** Let $G$ be a finite group, and let $H$ be a subgroup of $G$.
=--
END_THM

    assert_match_markup_parsed_as(Regexp.new(str1), str2)
  
    assert_markup_parsed_as(
        %{<p>SVG <animateColor title='MathML'><span class='newWikiWord'>} +
        %{Math ML<a href='../show/MathML'>?</a></span></animateColor></p>}, 
        "SVG <animateColor title='MathML'>MathML</animateColor>")
  
    assert_markup_parsed_as(
        %{<div class='maruku-equation'><math class='maruku-mathml' display='block' } +
        %{xmlns='http://www.w3.org/1998/Math/MathML'><mi>sin</mi><mo stretchy='false'>} +
        %{(</mo><mi>x</mi><mo stretchy='false'>)</mo><semantics><annotation-xml encoding='SVG1.1'>} +
        %{<svg></svg></annotation-xml></semantics></math><span class='maruku-eq-tex'><code style='display: none;'>} +
        %{\\sin(x) \\begin{svg}&lt;svg/&gt;\\end{svg}</code></span></div>},
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
        
        assert_markup_parsed_as(%{<p>You then needed to edit (or create) a user.js file in} +
          %{ your Mozilla profile, which read either (<span class='newWikiWord'>Mac OSX<a h} +
          %{ref='../show/MacOSX'>?</a></span>)</p>\n\n<pre><code>  user_pref(&quot;font.mat} +
          %{hfont-family&quot;, &quot;Math1,Math2,Math4,Symbol&quot;);</code></pre>},
        %{You then needed to edit (or create) a user.js file in your Mozilla profile, whic} +
          %{h read either (MacOSX)\n\n      user_pref("font.mathfont-family", "Math1,Math2,Math4,Symbol");})

    assert_markup_parsed_as(
        %{<p><math class='maruku-mathml' } +
        %{display='inline' xmlns='http://www.w3.org/1998/Math/MathML'>} +
        %{<mi>sin</mi><mo stretchy='false'>(</mo><mi>x</mi><mo stretchy='false'>)</mo></math> ecuasi\303\263n</p>},
        "$\\sin(x)$ ecuasi\303\263n")
   
    assert_markup_parsed_as(
        %{<p>ecuasi\303\263n</p>\n<div class='maruku-equation'><math class='maruku-mathml' } +
        %{display='block' xmlns='http://www.w3.org/1998/Math/MathML'><mi>sin</mi>} +
        %{<mo stretchy='false'>(</mo><mi>x</mi><mo stretchy='false'>)</mo></math>} +
        %{<span class='maruku-eq-tex'><code style='display: none;'>\\sin(x)</code></span></div>}, 
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
  
    assert_markup_parsed_as(
        %{<div class='maruku-equation'><math class='maruku-mathml' display='block' xmlns='http://w} +
        %{ww.w3.org/1998/Math/MathML'><mo>⋅</mo><mi>p</mi></math><span class='maruku-eq-tex'><code} +
        %{ style='display: none;'>\\cdot\np</code></span></div>},
        "$$\\cdot\np$$")
  
  end

  def test_footnotes
    assert_markup_parsed_as("<p>Ruby on Rails is a web-framework<sup id='fnref:1'><a href='#fn" +
    ":1' rel='footnote'>1</a></sup>. It uses the MVC<sup id='fnref:2'><a href='#fn:2' rel='foo" +
    "tnote'>2</a></sup> architecture pattern. It has its good points<sup id='fnref:3'><a href=" +
    "'#fn:3' rel='footnote'>3</a></sup>.</p>\n<div class='footnotes'><hr/><ol><li id='fn:1'>\n" +
    "<p>a reusable set of libraries <a href='#fnref:1' rev='footnote'>\342\206\251</a></p>\n</li><li" +
    " id='fn:2'>\n<p>Model View Controller <a href='#fnref:2' rev='footnote'>\342\206\251</a></p>\n<" +
    "/li><li id='fn:3'>\n<p>Here are its good points</p>\n\n<ol>\n<li>Ease of use</li>\n\n<li>" +
    "Rapid development</li>\n</ol>\n<a href='#fnref:3' rev='footnote'>\342\206\251</a></li></ol></div>",
    "Ruby on Rails is a web-framework[^framework]. It uses the MVC[^MVC] architecture pattern." +
    " It has its good points[^points].\n\n[^framework]: a reusable set of libraries\n\n[^MVC]:" +
    " Model View Controller\n\n[^points]: Here are its good points\n1. Ease of use\n2. Rapid d" +
    "evelopment")
  end

  def test_ial_in_lists

    assert_markup_parsed_as(
    "<ul>\n<li>item 1</li>\n\n<li style='color: red;'>" +
    "item 2</li>\n\n<li>item 3 continues here</li>\n</ul>",
    "* item 1\n* {: style=\"color:red\"} item 2\n* item 3\n   continues here\n")
    
    assert_markup_parsed_as(
    "<ol start='4'>\n<li>item 1</li>\n\n<li value='10'>" +
    "item 2</li>\n\n<li>item 3 continues here</li>\n</ol>",
    "1. item 1\n2. {: value=\"10\"} item 2\n13. item 3\n   continues here\n{: start=\"4\"}")

  end
  
  def test_utf8_in_lists

    assert_markup_parsed_as(
    "<ul>\n<li>\u041E\u0434\u0438\u043D</li>\n\n<li>\u0414" +
    "\u0432\u0430</li>\n\n<li>\u0422\u0440\u0438</li>\n</ul>",
    "* \u041E\u0434\u0438\u043D\n* \u0414\u0432\u0430\n* \u0422\u0440\u0438\n")
    
    assert_markup_parsed_as(
    "<ol>\n<li>\u041E\u0434\u0438\u043D</li>\n\n<li>\u0414"+
    "\u0432\u0430</li>\n\n<li>\u0422\u0440\u0438</li>\n</ol>",
    "1. \u041E\u0434\u0438\u043D\n2. \u0414\u0432\u0430\n3. \u0422\u0440\u0438\n")

  end

  def test_sick_lists

    assert_markup_parsed_as(
    "<ul>\n<li>item 1 19.</li>\n</ul>",
    "* item 1\n19.\n")

  end

  def test_have_latest_itex2mml  

      assert_markup_parsed_as(
        %{<p>equation <math class='maruku-mathml' displa} +
        %{y='inline' xmlns='http://www.w3.org/1998/Math/} +
        %{MathML'><mrow href='http://ex.com' xlink:href=} +
        %{'http://ex.com' xlink:type='simple' xmlns:xlin} +
        %{k='http://www.w3.org/1999/xlink'><mn>47.3</mn>} +
        %{</mrow><mn>47</mn><mo>,</mo><mn>3</mn><mn>47,3} +
        %{</mn></math></p>},
        "equation $\\href{http://ex.com}{47.3} 47,3 \\itexnum{47,3}$")

      assert_markup_parsed_as(
        %{<p>equation <math class='maruku-mathml' displa} +
        %{y='inline' xmlns='http://www.w3.org/1998/Math/} +
        %{MathML'><mi>A</mi><mi>\342\200\246</mi><mo>\342\253\275</mo><mi>B</} +
        %{mi></math></p>},
        "equation $A\\dots\\sslash B$")

      assert_markup_parsed_as(
        %{<p>boxed equation <math class='maruku-mathml' } +
        %{display='inline' xmlns='http://www.w3.org/1998} +
        %{/Math/MathML'><menclose notation='box'><mrow><} +
        %{menclose notation='updiagonalstrike'><mi>D</mi} +
        %{></menclose><mi>\317\210</mi><mo>=</mo><mn>0</} +
        %{mn></mrow></menclose></math></p>},
        "boxed equation $\\boxed{\\slash{D}\\psi=0}$")

      assert_markup_parsed_as(
        %{<p>equation <math class='maruku-mathml' displa} +
        %{y='inline' xmlns='http://www.w3.org/1998/Math/} +
        %{MathML'><mi>\316\265</mi><mo>\342\211\240</mo>} +
        %{<mi>\317\265</mi></math></p>},
        "equation $\\varepsilon\\neq\\epsilon$")

      assert_markup_parsed_as(
        %{<p>equation <math class='maruku-mathml' displa} +
        %{y='inline' xmlns='http://www.w3.org/1998/Math/} +
        %{MathML'><mi>A</mi><mo>=</mo><maction actiontyp} +
        %{e='tooltip'><mi>B</mi><mtext>Spoons!</mtext></} +
        %{maction></math></p>},
        "equation $A=\\tooltip{Spoons!}{B}$")

      assert_markup_parsed_as(
        %{<p>equation <math class='maruku-mathml' displa} +
        %{y='inline' xmlns='http://www.w3.org/1998/Math/} +
        %{MathML'><mi>A</mi><mpadded lspace='-100%width'} +
        %{ width='0'><mi>B</mi></mpadded></math></p>},
        "equation $A \\mathllap{B}$")

      assert_markup_parsed_as(
        %{<p>equation <math class='maruku-mathml' displa} +
        %{y='inline' xmlns='http://www.w3.org/1998/Math/} +
        %{MathML'><mi>A</mi><mo>\342\211\224</mo><mi>B</} +
        %{mi></math></p>},
        "equation $A \\coloneqq B$")
  
      assert_markup_parsed_as(
        %{<p>equation <math class='maruku-mathml' displa} +
        %{y='inline' xmlns='http://www.w3.org/1998/Math/} +
        %{MathML'><mi>A</mi><mo>\342\206\255</mo><mi>B</} +
        %{mi></math></p>},
        "equation $A \\leftrightsquigarrow B$")

    assert_markup_parsed_as(
        %{<p>equation <math class='maruku-mathml' displa} +
        %{y='inline' xmlns='http://www.w3.org/1998/Math/} +
        %{MathML'><munder><mi>A</mi><mo>\314\262</mo></m} +
        %{under></math></p>},
        "equation $\\underline{A}$")

    assert_markup_parsed_as(
        %{<p>equation <math class='maruku-mathml' } +
        %{display='inline' xmlns='http://www.w3.org/1998/Math/MathML'>} +
        %{<mi>A</mi><mo>\342\205\213</mo><mi>B</mi></math></p>},
        "equation $A \\invamp B$")

    assert_markup_parsed_as(
        %{<p>blackboard digits: <math class='maruku-mathml' display='} +
        %{inline' xmlns='http://www.w3.org/1998/Math/MathML'><mi>math} +
        %{bb</mi><mn>123</mn></math></p>},
        "blackboard digits: $\mathbb{123}$")

    assert_markup_parsed_as(
        %{<p>\\rlap: <math class='maruku-mathml' display='} +
        %{inline' xmlns='http://www.w3.org/1998/Math/MathML'>} +
        %{<mn>123</mn></math></p>},
        '\rlap: $\rlap{123}$')
  end
  
  def test_blahtex
    if Kernel::system('blahtex --help > /dev/null 2>&1')
      set_web_property :markup, :markdownPNG

      re = Regexp.new(
      %{<p>equation <span class='maruku-inline'><img alt='\\$a\\\\sin\\(\\\\theta\\)\\$' } +
      %{class='maruku-png' src='\.\./files/pngs/\\w+\.png' style='vertical-align: -0\.5} +
      %{(5)+6ex; height: 2\.3(3)+ex;'/></span></p>})
      assert_match_markup_parsed_as(re, 'equation $a\sin(\theta)$')

      re = Regexp.new(
      %{<div class='maruku-equation'><img alt='\\$a\\\\sin\\(\\\\theta\\)\\$' } +
      %{class='maruku-png' src='\.\./files/pngs/\\w+\.png' style='height: 2\.3(3)+} +
      %{33333ex;'/><span class='maruku-eq-tex'><code style='display: none;'>a\\\\sin} +
      %{\\(\\\\theta\\)<\/code><\/span><\/div>})
      assert_match_markup_parsed_as(re, '$$a\sin(\theta)$$')

    else
      print "\nBlahTeX not found ... skipping.\n"
    end
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
    
    set_web_property :markup, :markdownMML
    re = Regexp.new(
      '<h1 id=\'markdown_heading_\d{1,4}\'>Markdown heading</h1>\n\n' +
      "<p>h2. Textile heading</p>\n\n" +
      "<p><em>some</em> <strong>text</strong> <em>with</em> -styles-</p>\n\n" +
      "<ul>\n<li>list 1</li>\n\n<li>list 2</li>\n</ul>")
    
    assert_match_markup_parsed_as(re, textile_and_markdown)
    set_web_property :markup, :textile
    assert_markup_parsed_as(
      "<p>Markdown heading<br/>\n====</p>\n<h2>Textile heading</h2>" +
      "\n<p><strong>some</strong> <b>text</b> <em>with</em> <del>styles</del></p>" +
      "\n<ul>\n\t<li>list 1</li>\n\t<li>list 2</li>\n</ul>",
      textile_and_markdown)

# Mixed Textile+Markdown markup not supported by RedCloth 4.x    
    set_web_property :markup, :mixed
    assert_markup_parsed_as(
      "<h1>Markdown heading</h1>\n\n\n\t<h2>Textile heading</h2>\n\n\n\t" +
      "<p><strong>some</strong> <b>text</b> <em>with</em> <del>styles</del></p>\n\n\n\t" +
      "<ul>\n\t<li>list 1</li>\n\t\t<li>list 2</li>\n\t</ul>",
      textile_and_markdown)
  end

  def test_textile_pre
    set_web_property :markup, :textile
     assert_markup_parsed_as("<pre>\n<code>\n  a == 16\n</code>\n</pre>\n<p>foo bar" +
       "<br/>\n<pre><br/>\n<code>\n  b == 16\n</code><br/>\n</pre></p>",
     "<pre>\n<code>\n  a == 16\n</code>\n</pre>\nfoo bar\n<pre>\n<code>\n  b == 16\n</code>\n</pre>")
  end

  def test_rdoc
    set_web_property :markup, :rdoc
  
    @revision = Revision.new(:page => @page, :content => '+hello+ that SmartEngineGUI', 
        :author => Author.new('DavidHeinemeierHansson'))
  
    assert_equal "<tt>hello</tt> that <span class='newWikiWord'>Smart Engine GUI" +
        "<a href='../show/SmartEngineGUI'>?</a></span>", 
        x_test_renderer(@revision).display_content
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

  def test_content_with_utf8_in_strong
    assert_markup_parsed_as(
        "<p>Can we handle <strong>\u221E-gerbe</strong></p>", 
        "Can we handle **\u221E-gerbe**")
  end

  def test_content_with_redirected_link
    assert_markup_parsed_as(
        "<p>This is a redirected link: <a class='existingWikiWord' href='../show/liquor'>" +
	    "booze</a>. This is not: <span class='newWikiWord'>hooch<a href='../show/hooch'>?</a>" +
	    '</span></p>', 
        'This is a redirected link: [[booze]]. This is not: [[hooch]]')
  end

  def test_content_with_wikiword_in_equations
    assert_markup_parsed_as(
        "<p>should we go <a class='existingWikiWord' href='../show/ThatWay'>" +
	    "That Way</a> or</p>\n<div class='maruku-equation' id='eq:eq1'>" +
	    "<span class='maruku-eq-number'>(1)</span><math class='maruku-mathml' display='block' " +
	    "xmlns='http://www.w3.org/1998/Math/MathML'><mi>ThisWay</mi></math>" +
	    "<span class='maruku-eq-tex'><code style='display: none;'>ThisWay</code>" +
	    "</span></div>", 
        "should we go ThatWay or \n\\[ThisWay\\]\n")

    assert_markup_parsed_as(
        "<p>should we go <a class='existingWikiWord' href='../show/ThatWay'>" +
	    "That Way</a> or</p>\n<div class='maruku-equation'>" +
	    "<math class='maruku-mathml' display='block' " +
	    "xmlns='http://www.w3.org/1998/Math/MathML'><mi>ThisWay</mi></math>" +
	    "<span class='maruku-eq-tex'><code style='display: none;'>ThisWay</code>" +
	    "</span></div>", 
        "should we go ThatWay or \n$$ThisWay$$\n")
        
    assert_markup_parsed_as(
        "<p>should we go <a class='existingWikiWord' href='../show/ThatWay'>" +
	    "That Way</a> or</p>\n<div class='maruku-equation'>" +
	    "<math class='maruku-mathml' display='block' " +
	    "xmlns='http://www.w3.org/1998/Math/MathML'><mi>ThisWay</mi><mi>$</mi>" +
	    "<mn>100</mn><mi>ThatWay</mi></math>" +
	    "<span class='maruku-eq-tex'><code style='display: none;'>ThisWay \\$100 " +
	    "ThatWay</code></span></div>", 
        "should we go ThatWay or \n$$ThisWay \\$100 ThatWay $$\n")

    assert_markup_parsed_as(
        "<p>should we go <a class='existingWikiWord' href='../show/ThatWay'>" +
	    "That Way</a> or <math class='maruku-mathml' display='inline' " +
	    "xmlns='http://www.w3.org/1998/Math/MathML'><mi>ThisWay</mi></math> today.</p>", 
        "should we go ThatWay or <math class='maruku-mathml' display='inline' " +
	    "xmlns='http://www.w3.org/1998/Math/MathML'><mi>ThisWay</mi></math> today.")

    assert_markup_parsed_as(
        "<p>should we go <a class='existingWikiWord' href='../show/ThatWay'>" +
	    "That Way</a> or <math class='maruku-mathml' display='inline' " +
	    "xmlns='http://www.w3.org/1998/Math/MathML'><mi>ThisWay</mi></math>.</p>", 
        "should we go ThatWay or $ThisWay$.")
  end
  
  def test_content_with_wikiword_in_equations_textile
    set_web_property :markup, :textile
    assert_markup_parsed_as(
      "<p>$$<span class='newWikiWord'>foo<a href='../show/foo'>?" +
      "</a></span>$$<br/>\n$<span class='newWikiWord'>foo<a " +
      "href='../show/foo'>?</a></span>$</p>",
      "$$[[foo]]$$\n$[[foo]]$")
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

  def test_inline_html
    set_web_property :markup, :markdownMML
    assert_markup_parsed_as(
      "<p>We discuss the general abstract <a href='http://nlab.mathforge.org/nlab/show/cohesive+(infinity%2C1)-topos#Structures'>structures in a cohesive (\u221E,1)-topos</a> realized.</p>", 
      "We discuss the general abstract\n<a href=\"http://nlab.mathforge.org/nlab/show/cohesive+(infinity%2C1)-topos#Structures\">structures in a cohesive (\u221E,1)-topos</a> realized.")
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
      "<p>This &lt;IMG SRC='http://hobix.com/sample.jpg' alt=''&gt;&lt;/IMG&gt; is an inline image link.</p>", 
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
      '<p>&lt;i&gt;&lt;b&gt;&lt;/i&gt;&lt;/b&gt;</p>', 
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
      '<p>[[test]]&amp;<a href=\'a&amp;b\'>shebang</a> &lt;script&gt;alert(&quot;xss!&quot;);&lt;/script&gt; *foo*</p>',
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
        "<annotation-xml encoding='SVG1.1'><svg></svg></annotation-xml></semantics></math> in kinda " +
        "<a class='existingWikiWord' href='ThatWay.html'>That Way</a> in " +
        "<span class='newWikiWord'>His Way</span> though " +
        %{<a class='existingWikiWord' href='MyWay.html'>My Way</a> OverThere \342\200\223 see } +
        "<a class='existingWikiWord' href='SmartEngine.html'>Smart Engine</a> in that " +
        "<span class='newWikiWord'>Smart Engine GUI</span></p>", 
        x_test_renderer(@revision).display_content_for_export
  end
  
  def test_double_replacing
    @revision.content = "VersionHistory\r\n\r\ncry VersionHistory"
    assert_equal "<p><span class='newWikiWord'>Version History" +
        "<a href='../show/VersionHistory'>?</a></span></p>\n\n<p>cry " +
        "<span class='newWikiWord'>Version History<a href='../show/VersionHistory'>?</a>" +
        '</span></p>', 
        x_test_renderer(@revision).display_content
  
    @revision.content = "f\r\nVersionHistory\r\n\r\ncry VersionHistory"
    assert_equal "<p>f <span class='newWikiWord'>Version History" +
        "<a href='../show/VersionHistory'>?</a></span></p>\n\n<p>cry " +
        "<span class='newWikiWord'>Version History<a href='../show/VersionHistory'>?</a>" +
        "</span></p>", 
        x_test_renderer(@revision).display_content
  end  
  
  def test_difficult_wiki_words
    @revision.content = "[[It's just awesome GUI!]]"
    assert_equal "<p><span class='newWikiWord'>It&#39;s just awesome GUI!" +
        "<a href='../show/It%27s+just+awesome+GUI%21'>?</a></span></p>", 
        x_test_renderer(@revision).display_content
  end
  
  def test_revisions_diff
    Revision.create(:page => @page, :content => 'What a blue and lovely morning', 
        :author => Author.new('DavidHeinemeierHansson'), :revised_at => Time.now)
    Revision.create(:page => @page, :content => 'What a red and lovely morning today', 
        :author => Author.new('DavidHeinemeierHansson'), :revised_at => Time.now)

    @page.reload
    assert_equal "<p><span> What a<del class='diffmod'> blue</del><ins class='diffmod'> red" +
        "</ins> and lovely morning<ins class='diffins'> today</ins></span></p>", x_test_renderer(@page.revisions.last).display_diff
  end
  
  def test_nowiki_sanitization
    assert_markup_parsed_as('<p>This sentence contains <span>a &amp; b</span> ' +
     '&lt;script&gt;alert(&quot;XSS!&quot;);&lt;/script&gt;. Do not touch!</p>',
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
    FileUtils.rm_rf("#{RAILS_ROOT}/webs/wiki1/files/*")
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
      "<p><video controls='controls' src='../file/square.jpg'>Blue Square</video></p>",
      '[[square.jpg|Blue Square:video]]')
    assert_markup_parsed_as(
      "<p><audio controls='controls' src='../file/square.jpg'>Blue Square</audio></p>",
      '[[square.jpg|Blue Square:audio]]')
    assert_markup_parsed_as( 
      "<p><a class='existingWikiWord' href='../file/square.jpg' title='Square'>Square</a></p>",
      '[[square.jpg:file]]')
  end
  
  def test_link_to_pic_and_file_null_desc
    WikiFile.delete_all
    require 'fileutils'
    FileUtils.rm_rf("#{RAILS_ROOT}/webs/wiki1/files/*")
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
  	  "<p><a class='existingWikiWord' href='../show/HomePage'>HomePage</a></p>",
  	  '[[wiki1:HomePage]]')
  end
  
  def test_wiki_link_with_colon_interwiki
  	assert_markup_parsed_as(
  	  "<p><a class='existingWikiWord' href='../../instiki/show/HomePage' title='instiki'>HomePage</a></p>",
  	  '[[instiki:HomePage]]')
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
        Time.local(2004, 4, 4, 16, 50), 'AlexeyVerkhovsky', x_test_renderer)
        
    references = new_page.wiki_references(true)
    assert_equal 2, references.size
    assert_equal 'HomePage', references[0].referenced_name
    assert_equal WikiReference::LINKED_PAGE, references[0].link_type
    assert_equal 'NewPage', references[1].referenced_name
    assert_equal WikiReference::LINKED_PAGE, references[1].link_type
  end

  def test_references_creation_includes
    new_page = @web.add_page('NewPage', '[[!include IncludedPage]]',
        Time.local(2004, 4, 4, 16, 50), 'AlexeyVerkhovsky', x_test_renderer)
        
    references = new_page.wiki_references(true)
    assert_equal 1, references.size
    assert_equal 'IncludedPage', references[0].referenced_name
    assert_equal WikiReference::INCLUDED_PAGE, references[0].link_type
  end

  def test_references_creation_redirects
    new_page = @web.add_page('NewPage', '[[!redirects OtherPage]]',
        Time.local(2004, 4, 4, 16, 50), 'AlexeyVerkhovsky', x_test_renderer)
        
    references = new_page.wiki_references(true)
    assert_equal 1, references.size
    assert_equal 'OtherPage', references[0].referenced_name
    assert_equal WikiReference::REDIRECTED_PAGE, references[0].link_type
  end

   def test_references_creation_redirects_in_included_page
    new_page = @web.add_page('NewPage', "[[!redirects OtherPage]]\ncategory: plants",
        Time.local(2004, 4, 4, 16, 50), 'AlexeyVerkhovsky', x_test_renderer)
    second_page = @web.add_page('SecondPage', '[[!include NewPage]]',
        Time.local(2004, 4, 4, 16, 50), 'AlexeyVerkhovsky', x_test_renderer)
        
    references = new_page.wiki_references(true)
    assert_equal 2, references.size
    assert_equal 'OtherPage', references[0].referenced_name
    assert_equal WikiReference::REDIRECTED_PAGE, references[0].link_type
    assert_equal 'plants', references[1].referenced_name
    assert_equal WikiReference::CATEGORY, references[1].link_type

    references = second_page.wiki_references(true)
    assert_equal 1, references.size
    assert_equal 'NewPage', references[0].referenced_name
    assert_equal WikiReference::INCLUDED_PAGE, references[0].link_type
  end

 def test_references_creation_categories
    new_page = @web.add_page('NewPage', "Foo\ncategory: NewPageCategory",
        Time.local(2004, 4, 4, 16, 50), 'AlexeyVerkhovsky', x_test_renderer)

    references = new_page.wiki_references(true)
    assert_equal 1, references.size
    assert_equal 'NewPageCategory', references[0].referenced_name
    assert_equal WikiReference::CATEGORY, references[0].link_type
  end

  def test_references_creation_sanitized_categories
    new_page = @web.add_page('NewPage', "Foo\ncategory: <script>alert('XSS');</script>",
        Time.local(2004, 4, 4, 16, 50), 'AlexeyVerkhovsky', x_test_renderer)

    references = new_page.wiki_references(true)
    assert_equal 1, references.size
    assert_equal "&lt;script&gt;alert(&#39;XSS&#39;);&lt;/script&gt;", references[0].referenced_name
    assert_equal WikiReference::CATEGORY, references[0].link_type
  end
  
  def test_rendering_included_page_under_different_modes
    included = @web.add_page('Included', 'link to HomePage', Time.now, 'AnAuthor', x_test_renderer)
    main = @web.add_page('Main', '[[!include Included]]', Time.now, 'AnAuthor', x_test_renderer)
    
    assert_equal "<p>link to <a class='existingWikiWord' href='../show/HomePage'>Home Page</a></p>", 
                 x_test_renderer(main).display_content
    assert_equal "<p>link to <a class='existingWikiWord' href='../published/HomePage'>Home Page</a></p>",
                 x_test_renderer(main).display_published
    assert_equal "<p>link to <a class='existingWikiWord' href='HomePage.html'>Home Page</a></p>", 
                 x_test_renderer(main).display_content_for_export
  end

  def test_rendering_included_page_backslashes_in_equations
    included = @web.add_page('Included', '\\\\ $\begin{matrix} a \\\\ b\end{matrix}$', Time.now, 'AnAuthor', x_test_renderer)
    main = @web.add_page('Main', '[[!include Included]]', Time.now, 'AnAuthor', x_test_renderer)
    
    assert_equal "<p>\\ <math class='maruku-mathml' display='inline' " +
                 "xmlns='http://www.w3.org/1998/Math/MathML'><mrow><mtable rowspacing='0.5ex'>" +
                 "<mtr><mtd><mi>a</mi></mtd></mtr> <mtr><mtd><mi>b</mi></mtd></mtr></mtable>" +
                 "</mrow></math></p>", 
                 x_test_renderer(main).display_content
  end

  private

  def add_sample_pages
    @in_love = @web.add_page('EverBeenInLove', 'Who am I me', 
        Time.local(2004, 4, 4, 16, 50), 'DavidHeinemeierHansson', x_test_renderer)
    @hated = @web.add_page('EverBeenHated', 'I am me EverBeenHated', 
        Time.local(2004, 4, 4, 16, 51), 'DavidHeinemeierHansson', x_test_renderer)
  end

  def assert_markup_parsed_as(expected_output, input)
    revision = Revision.new(:page => @page, :content => input, :author => Author.new('AnAuthor'))
    assert_equal expected_output, x_test_renderer(revision).display_content(true), 'Rendering output not as expected'
  end

  def assert_match_markup_parsed_as(expected_output, input)
    revision = Revision.new(:page => @page, :content => input, :author => Author.new('AnAuthor'))
    assert_match expected_output, x_test_renderer(revision).display_content, 'Rendering output not as expected'
  end

  def rendered_content(page)
    x_test_renderer(page.revisions.last).display_content
  end
  
end
