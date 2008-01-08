Write a comment here
*** Parameters: ***
{} # params 
*** Markdown input: ***
[test][]:

*** Output of inspect ***
md_el(:document,[md_par([md_link(["test"],"test"), ":"])],{},[])
*** Output of to_html ***
<p><span>test</span>:</p>
*** Output of to_latex ***
test:
*** Output of to_md ***
test:
*** Output of to_s ***
test:
*** EOF ***



	OK!



*** Output of Markdown.pl ***
<p>[test][]:</p>

*** Output of Markdown.pl (parsed) ***
Error: #<NoMethodError: private method `write_children' called for <div> ... </>:REXML::Element>
