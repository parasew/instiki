Write a comment here
*** Parameters: ***
{}
*** Markdown input: ***
<table markdown='1'>
	Blah
	<thead>
		<td>*em*</td>
	</thead>
</table>

*** Output of inspect ***
md_el(:document,[
	md_html("<table markdown='1'>\n\tBlah\n\t<thead>\n\t\t<td>*em*</td>\n\t</thead>\n</table>")
],{},[])
*** Output of to_html ***
<table>Blah<thead>
		<td><em>em</em></td>
	</thead>
</table>
*** Output of to_latex ***

*** Output of to_md ***

*** Output of to_s ***

*** EOF ***



	OK!



*** Output of Markdown.pl ***
<table markdown='1'>
    Blah
    <thead>
        <td>*em*</td>
    </thead>
</table>

*** Output of Markdown.pl (parsed) ***
Error: #<NoMethodError: private method `write_children' called for <div> ... </>:REXML::Element>
