This shows how Maruku recovers from parsing errors
*** Parameters: ***
{:on_error=>:warning}
*** Markdown input: ***
Search on [Google images][ 	GoOgle search ]
*** Output of inspect ***
md_el(:document,[md_par(["Search on Google imagesGoOgle search ]"])],{},[])
*** Output of to_html ***
<p>Search on Google imagesGoOgle search ]</p>
*** Output of to_latex ***
Search on Google imagesGoOgle search ]
*** Output of to_md ***
Search on Google imagesGoOgle search ]
*** Output of to_s ***
Search on Google imagesGoOgle search ]
*** EOF ***



	OK!



*** Output of Markdown.pl ***
<p>Search on [Google images][  GoOgle search ]</p>

*** Output of Markdown.pl (parsed) ***
Error: #<NoMethodError: private method `write_children' called for <div> ... </>:REXML::Element>
