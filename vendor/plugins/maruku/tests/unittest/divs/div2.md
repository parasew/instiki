Write a comment here
*** Parameters: ***
require 'maruku/ext/div'; {} # params 
*** Markdown input: ***
+--
ciao
=--
*** Output of inspect ***
md_el(:document,[md_el(:div,[md_par(["ciao"])],{},[])],{},[])
*** Output of to_html ***
<div>
<p>ciao</p>
</div>
*** Output of to_latex ***

*** Output of to_md ***
ciao
*** Output of to_s ***
ciao
*** EOF ***



	OK!



*** Output of Markdown.pl ***
<p>+--
ciao
=--</p>

*** Output of Markdown.pl (parsed) ***
Error: #<NoMethodError: private method `write_children' called for <div> ... </>:REXML::Element>
