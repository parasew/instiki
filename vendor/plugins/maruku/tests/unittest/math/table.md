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




Failed tests:   [:to_html] 

*** Output of inspect ***
md_el(:document,[
	md_html("<table markdown='1'>\n\t$\\alpha$\n\t<thead>\n\t\t<td>$\\beta$</td>\n\t</thead>\n</table>")
],{},[])
*** Output of to_html ***
-----| WARNING | -----
<table><span class='maruku-inline'><math class='maruku-mathml' display='inline' xmlns='http://www.w3.org/1998/Math/MathML'><mi>&alpha;</mi></math></span><thead>
		<td><span class='maruku-inline'><math class='maruku-mathml' display='inline' xmlns='http://www.w3.org/1998/Math/MathML'><mi>&beta;</mi></math></span></td>
	</thead>
</table>
*** Output of to_latex ***

*** Output of to_md ***

*** Output of to_s ***

*** Output of Markdown.pl ***
<table markdown='1'>
    <math xmlns='http://www.w3.org/1998/Math/MathML' display='inline'><mi>&alpha;</mi></math>
    <thead>
        <td><math xmlns='http://www.w3.org/1998/Math/MathML' display='inline'><mi>&beta;</mi></math></td>
    </thead>
</table>

*** Output of Markdown.pl (parsed) ***
<div>
 <table markdown='1'>
  <math display='inline' xmlns='http://www.w3.org/1998/Math/MathML'>
   <mi>
    &alpha;
   </mi>
  </math>
  <thead>
   <td>
    <math display='inline' xmlns='http://www.w3.org/1998/Math/MathML'>
     <mi>
      &beta;
     </mi>
    </math>
   </td>
  </thead>
 </table>
</div>