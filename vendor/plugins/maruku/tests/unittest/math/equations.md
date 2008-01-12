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
<math xmlns='http://www.w3.org/1998/Math/MathML' display='block'><mi>x</mi><mo>=</mo><mi>y</mi></math>

<math xmlns='http://www.w3.org/1998/Math/MathML' display='block'><mi>x</mi><mo>=</mo><mi>y</mi></math>

<math xmlns='http://www.w3.org/1998/Math/MathML' display='block'><mi>x</mi><mo>=</mo><mi>y</mi></math>

<math xmlns='http://www.w3.org/1998/Math/MathML' display='block'><mi>x</mi><mo>=</mo><mi>y</mi></math>

*** Output of Markdown.pl (parsed) ***
<div>
 <math display='block' xmlns='http://www.w3.org/1998/Math/MathML'>
  <mi>
   x
  </mi>
  <mo>
   =
  </mo>
  <mi>
   y
  </mi>
 </math>
 <math display='block' xmlns='http://www.w3.org/1998/Math/MathML'>
  <mi>
   x
  </mi>
  <mo>
   =
  </mo>
  <mi>
   y
  </mi>
 </math>
 <math display='block' xmlns='http://www.w3.org/1998/Math/MathML'>
  <mi>
   x
  </mi>
  <mo>
   =
  </mo>
  <mi>
   y
  </mi>
 </math>
 <math display='block' xmlns='http://www.w3.org/1998/Math/MathML'>
  <mi>
   x
  </mi>
  <mo>
   =
  </mo>
  <mi>
   y
  </mi>
 </math>
</div>