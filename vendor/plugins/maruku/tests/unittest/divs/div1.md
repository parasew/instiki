Write a comment here
*** Parameters: ***
require 'maruku/ext/div'; {} # params 
*** Markdown input: ***
+---------
| text
+----------

+---------
|text

+--
 text
 
=--


 +---------
 | text
 +----------

 +---------
 |text

 +--
 text

 =--


  +---------
  | text
  +----------

  +---------
  |text

  +--
  text

  =--

   +---------
   | text
   +----------

   +---------
   |text

   +--
   text

   =--

*** Output of inspect ***
md_el(:document,[
	md_el(:div,[md_par(["text"])],{},[]),
	md_el(:div,[md_par(["text"])],{},[]),
	md_el(:div,[md_par(["text"])],{},[]),
	md_el(:div,[md_par(["text"])],{},[]),
	md_el(:div,[md_par(["text"])],{},[]),
	md_el(:div,[md_par(["text"])],{},[]),
	md_el(:div,[md_par(["text"])],{},[]),
	md_el(:div,[md_par(["text"])],{},[]),
	md_el(:div,[md_par(["text"])],{},[]),
	md_el(:div,[md_par(["text"])],{},[]),
	md_el(:div,[md_par(["text"])],{},[]),
	md_el(:div,[md_par(["text"])],{},[])
],{},[])
*** Output of to_html ***
<div>
<p>text</p>
</div>

<div>
<p>text</p>
</div>

<div>
<p>text</p>
</div>

<div>
<p>text</p>
</div>

<div>
<p>text</p>
</div>

<div>
<p>text</p>
</div>

<div>
<p>text</p>
</div>

<div>
<p>text</p>
</div>

<div>
<p>text</p>
</div>

<div>
<p>text</p>
</div>

<div>
<p>text</p>
</div>

<div>
<p>text</p>
</div>
*** Output of to_latex ***

*** Output of to_md ***
text

text

text

text

text

text

text

text

text

text

text

text
*** Output of to_s ***
texttexttexttexttexttexttexttexttexttexttexttext
*** EOF ***



	OK!



*** Output of Markdown.pl ***
<p>+---------
| text
+----------</p>

<p>+---------
|text</p>

<p>+--
 text</p>

<p>=--</p>

<p>+---------
 | text
 +----------</p>

<p>+---------
 |text</p>

<p>+--
 text</p>

<p>=--</p>

<p>+---------
  | text
  +----------</p>

<p>+---------
  |text</p>

<p>+--
  text</p>

<p>=--</p>

<p>+---------
   | text
   +----------</p>

<p>+---------
   |text</p>

<p>+--
   text</p>

<p>=--</p>

*** Output of Markdown.pl (parsed) ***
Error: #<NoMethodError: private method `write_children' called for <div> ... </>:REXML::Element>
