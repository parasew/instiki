Write a comment here
*** Parameters: ***
{}
*** Markdown input: ***

$$ x = y $$

$$ x 
= y $$

$$ 
x = y $$

$$ x = y 
$$

*** Output of inspect ***
md_el(:document,[
	md_par(["$$ x = y $$"]),
	md_el(:header,["$$ x"],{:level=>1},[]),
	md_par(["$$ x = y $$"]),
	md_par(["$$ x = y $$"])
],{},[])
*** Output of to_html ***
<p>$$ x = y $$</p>

<h1 id='_x'>$$ x</h1>

<p>$$ x = y $$</p>

<p>$$ x = y $$</p>
*** Output of to_latex ***
\$\$ x = y \$\$

\hypertarget{_x}{}\section*{{\$\$ x}}\label{_x}

\$\$ x = y \$\$

\$\$ x = y \$\$
*** Output of to_md ***
$$ x = y $$

$$ x$$ x = y $$

$$ x = y $$
*** Output of to_s ***
$$ x = y $$$$ x$$ x = y $$$$ x = y $$
*** EOF ***



	OK!



*** Output of Markdown.pl ***
<p>$$ x = y $$</p>

<p>$$ x 
= y $$</p>

<p>$$ 
x = y $$</p>

<p>$$ x = y 
$$</p>

*** Output of Markdown.pl (parsed) ***
Error: #<NoMethodError: private method `write_children' called for <div> ... </>:REXML::Element>
