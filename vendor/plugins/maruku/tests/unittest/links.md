Write a comment abouth the test here.
*** Parameters: ***
{:on_error=>:warning}
*** Markdown input: ***

Search on [Google][]

Search on [Google] []

Search on [Google] [google]

Search on [Google] [Google]

Search on [Google images][]

Inline: [Google images](http://google.com)

Inline with title: [Google images](http://google.com "Title")

Inline with title: [Google images]( http://google.com  "Title" )


Search on <http://www.gogole.com> or <http://Here.com> or ask <mailto:bill@google.com>
or you might ask bill@google.com.

If all else fails, ask [Google](http://www.google.com)
	
[google]: http://www.google.com

[google2]: http://www.google.com 'Single quotes'

[google3]: http://www.google.com "Double quotes"

[google4]: http://www.google.com (Parenthesis)

[Google Search]: 
 http://www.google.com "Google search"

[Google Images]: 
 http://images.google.com  (Google images)
*** Output of inspect ***
md_el(:document,[
	md_par(["Search on ", md_link(["Google"],"google")]),
	md_par(["Search on ", md_link(["Google"],"google")]),
	md_par(["Search on ", md_link(["Google"],"google")]),
	md_par(["Search on ", md_link(["Google"],"google")]),
	md_par(["Search on ", md_link(["Google images"],"google_images")]),
	md_par(["Inline: ", md_im_link(["Google images"], "http://google.com", nil)]),
	md_par([
		"Inline with title: ",
		md_im_link(["Google images"], "http://google.com", "Title")
	]),
	md_par([
		"Inline with title: ",
		md_im_link(["Google images"], "http://google.com", "Title")
	]),
	md_par([
		"Search on ",
		md_url("http://www.gogole.com"),
		" or ",
		md_url("http://Here.com"),
		" or ask ",
		md_email("bill@google.com"),
		" or you might ask bill@google.com."
	]),
	md_par([
		"If all else fails, ask ",
		md_im_link(["Google"], "http://www.google.com", nil)
	]),
	md_ref_def("google", "http://www.google.com", {:title=>nil}),
	md_ref_def("google2", "http://www.google.com", {:title=>"Single quotes"}),
	md_ref_def("google3", "http://www.google.com", {:title=>"Double quotes"}),
	md_ref_def("google4", "http://www.google.com", {:title=>"Parenthesis"}),
	md_ref_def("google_search", "http://www.google.com", {:title=>"Google search"}),
	md_ref_def("google_images", "http://images.google.com", {:title=>"Google images"})
],{},[])
*** Output of to_html ***
<p>Search on <a href='http://www.google.com'>Google</a></p>

<p>Search on <a href='http://www.google.com'>Google</a></p>

<p>Search on <a href='http://www.google.com'>Google</a></p>

<p>Search on <a href='http://www.google.com'>Google</a></p>

<p>Search on <a href='http://images.google.com' title='Google images'>Google images</a></p>

<p>Inline: <a href='http://google.com'>Google images</a></p>

<p>Inline with title: <a href='http://google.com' title='Title'>Google images</a></p>

<p>Inline with title: <a href='http://google.com' title='Title'>Google images</a></p>

<p>Search on <a href='http://www.gogole.com'>http://www.gogole.com</a> or <a href='http://Here.com'>http://Here.com</a> or ask <a href='mailto:bill@google.com'>&#098;&#105;&#108;&#108;&#064;&#103;&#111;&#111;&#103;&#108;&#101;&#046;&#099;&#111;&#109;</a> or you might ask bill@google.com.</p>

<p>If all else fails, ask <a href='http://www.google.com'>Google</a></p>
*** Output of to_latex ***
Search on \href{http://www.google.com}{Google}

Search on \href{http://www.google.com}{Google}

Search on \href{http://www.google.com}{Google}

Search on \href{http://www.google.com}{Google}

Search on \href{http://images.google.com}{Google images}

Inline: \href{http://google.com}{Google images}

Inline with title: \href{http://google.com}{Google images}

Inline with title: \href{http://google.com}{Google images}

Search on \href{http://www.gogole.com}{http\char58\char47\char47www\char46gogole\char46com} or \href{http://Here.com}{http\char58\char47\char47Here\char46com} or ask \href{mailto:bill@google.com}{bill\char64google\char46com} or you might ask bill@google.com.

If all else fails, ask \href{http://www.google.com}{Google}
*** Output of to_md ***
Search on Google

Search on Google

Search on Google

Search on Google

Search on Google images

Inline: Google images

Inline with title: Google images

Inline with title: Google images

Search on or or ask or you might ask
bill@google.com.

If all else fails, ask Google
*** Output of to_s ***
Search on GoogleSearch on GoogleSearch on GoogleSearch on GoogleSearch on Google imagesInline: Google imagesInline with title: Google imagesInline with title: Google imagesSearch on  or  or ask  or you might ask bill@google.com.If all else fails, ask Google
*** EOF ***



	OK!



*** Output of Markdown.pl ***
<p>Search on <a href="http://www.google.com">Google</a></p>

<p>Search on <a href="http://www.google.com">Google</a></p>

<p>Search on <a href="http://www.google.com">Google</a></p>

<p>Search on <a href="http://www.google.com">Google</a></p>

<p>Search on <a href="http://images.google.com" title="Google images">Google images</a></p>

<p>Inline: <a href="http://google.com">Google images</a></p>

<p>Inline with title: <a href="http://google.com" title="Title">Google images</a></p>

<p>Inline with title: <a href="http://google.com  "Title"">Google images</a></p>

<p>Search on <a href="http://www.gogole.com">http://www.gogole.com</a> or <a href="http://Here.com">http://Here.com</a> or ask <a href="&#109;&#x61;&#105;l&#116;o:&#x62;&#x69;&#108;l&#64;&#x67;&#111;&#111;&#103;&#x6C;&#x65;&#46;&#99;&#x6F;&#x6D;">&#x62;&#x69;&#108;l&#64;&#x67;&#111;&#111;&#103;&#x6C;&#x65;&#46;&#99;&#x6F;&#x6D;</a>
or you might ask bill@google.com.</p>

<p>If all else fails, ask <a href="http://www.google.com">Google</a></p>

<p>[google2]: http://www.google.com 'Single quotes'</p>

*** Output of Markdown.pl (parsed) ***
Error: #<REXML::ParseException: #<REXML::ParseException: Missing end tag for 'p' (got "div")
Line: 
Position: 
Last 80 unconsumed characters:
>
/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/lib/ruby/1.8/rexml/parsers/baseparser.rb:320:in `pull'
/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/lib/ruby/1.8/rexml/parsers/treeparser.rb:21:in `parse'
/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/lib/ruby/1.8/rexml/document.rb:204:in `build'
/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/lib/ruby/1.8/rexml/document.rb:42:in `initialize'
bin/marutest:200:in `new'
bin/marutest:200:in `run_test'
bin/marutest:274:in `marutest'
bin/marutest:271:in `each'
bin/marutest:271:in `marutest'
bin/marutest:346
...
Missing end tag for 'p' (got "div")
Line: 
Position: 
Last 80 unconsumed characters:

Line: 
Position: 
Last 80 unconsumed characters:
>
