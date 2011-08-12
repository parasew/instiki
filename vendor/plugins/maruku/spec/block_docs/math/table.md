Write a comment here
*** Parameters: ***
require 'maruku/ext/math';{:html_math_engine => 'itex2mml' }
*** Markdown input: ***
<table markdown='1'>
	$\alpha$
	<thead>
		<td>$\beta$</td>
	</thead>
</table>
*** Output of inspect ***
md_el(:document,[
	md_html("<table markdown='1'>\n\t$\\alpha$\n\t<thead>\n\t\t<td>$\\beta$</td>\n\t</thead>\n</table>")
],{},[])
*** Output of to_html ***
<table><math xmlns="http://www.w3.org/1998/Math/MathML" display="inline" class="maruku-mathml"><mi>&#x3B1;</mi></math><thead>
		<td><math xmlns="http://www.w3.org/1998/Math/MathML" display="inline" class="maruku-mathml"><mi>&#x3B2;</mi></math></td>
	</thead>
</table>
*** Output of to_latex ***

*** Output of to_md ***

*** Output of to_s ***

