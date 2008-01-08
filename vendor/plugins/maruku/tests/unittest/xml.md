Write a comment here
*** Parameters: ***
{:on_error=>:raise}
*** Markdown input: ***

<svg:svg/>

<svg:svg 
width="600px" height="400px">
  <svg:g id="group">
	<svg:circle id="circ1" r="1cm" cx="3cm" cy="3cm" style="fill:red;"></svg:circle>
	<svg:circle id="circ2" r="1cm" cx="7cm" cy="3cm" style="fill:red;" />
  </svg:g>
</svg:svg>

*** Output of inspect ***
md_el(:document,[
	md_html("<svg:svg/>"),
	md_html("<svg:svg \nwidth=\"600px\" height=\"400px\">\n  <svg:g id=\"group\">\n\t<svg:circle id=\"circ1\" r=\"1cm\" cx=\"3cm\" cy=\"3cm\" style=\"fill:red;\"></svg:circle>\n\t<svg:circle id=\"circ2\" r=\"1cm\" cx=\"7cm\" cy=\"3cm\" style=\"fill:red;\" />\n  </svg:g>\n</svg:svg>")
],{},[])
*** Output of to_html ***
<svg:svg /><svg:svg height='400px' width='600px'>
  <svg:g id='group'>
	<svg:circle cy='3cm' id='circ1' r='1cm' cx='3cm' style='fill:red;' />
	<svg:circle cy='3cm' id='circ2' r='1cm' cx='7cm' style='fill:red;' />
  </svg:g>
</svg:svg>
*** Output of to_latex ***

*** Output of to_md ***

*** Output of to_s ***

*** EOF ***



	OK!



*** Output of Markdown.pl ***
<p><svg:svg/></p>

<p><svg:svg 
width="600px" height="400px">
  <svg:g id="group">
    <svg:circle id="circ1" r="1cm" cx="3cm" cy="3cm" style="fill:red;"></svg:circle>
    <svg:circle id="circ2" r="1cm" cx="7cm" cy="3cm" style="fill:red;" />
  </svg:g>
</svg:svg></p>

*** Output of Markdown.pl (parsed) ***
Error: #<NoMethodError: private method `write_children' called for <div> ... </>:REXML::Element>
