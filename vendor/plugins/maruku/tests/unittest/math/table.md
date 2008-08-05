Write a comment here
*** Parameters: ***
{}
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
<table><span class='maruku-inline'><code class='maruku-mathml'>\alpha</code></span><thead>
		<td><span class='maruku-inline'><code class='maruku-mathml'>\beta</code></span></td>
	</thead>
</table>
*** Output of to_latex ***

*** Output of to_md ***

*** Output of to_s ***

*** EOF ***



	OK!



*** Output of Markdown.pl ***
(not used anymore)
*** Output of Markdown.pl (parsed) ***
(not used anymore)