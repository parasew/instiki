Write a comment abouth the test here.
*** Parameters: ***
{}
*** Markdown input: ***
* * *

***

*****

- - -

---------------------------------------


*** Output of inspect ***
md_el(:document,[
	md_el(:hrule,[],{},[]),
	md_el(:hrule,[],{},[]),
	md_el(:hrule,[],{},[]),
	md_el(:hrule,[],{},[]),
	md_el(:hrule,[],{},[])
],{},[])
*** Output of to_html ***
<hr /><hr /><hr /><hr /><hr />
*** Output of to_latex ***
\vspace{.5em} \hrule \vspace{.5em}

\vspace{.5em} \hrule \vspace{.5em}

\vspace{.5em} \hrule \vspace{.5em}

\vspace{.5em} \hrule \vspace{.5em}

\vspace{.5em} \hrule \vspace{.5em}
*** Output of to_md ***

*** Output of to_s ***

*** EOF ***



	OK!



*** Output of Markdown.pl ***
<hr />

<hr />

<hr />

<hr />

<hr />

*** Output of Markdown.pl (parsed) ***
Error: #<NoMethodError: private method `write_children' called for <div> ... </>:REXML::Element>
