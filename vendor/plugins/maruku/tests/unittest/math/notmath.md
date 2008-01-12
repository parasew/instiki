
*** Parameters: ***
require 'maruku/ext/math'; {:math_enabled => false}
*** Markdown input: ***

This is not $math$.

\[ \alpha \]

*** Output of inspect ***
md_el(:document,[md_par(["This is not $math$."]), md_par(["[ \\alpha ]"])],{},[])
*** Output of to_html ***
<p>This is not $math$.</p>

<p>[ \alpha ]</p>
*** Output of to_latex ***
This is not \$math\$.

[ $\backslash$alpha ]
*** Output of to_md ***
This is not $math$.

[ \alpha ]
*** Output of to_s ***
This is not $math$.[ \alpha ]
*** EOF ***



	OK!



*** Output of Markdown.pl ***
<p>This is not <math xmlns='http://www.w3.org/1998/Math/MathML' display='inline'><mi>math</mi></math>.</p>

<math xmlns='http://www.w3.org/1998/Math/MathML' display='block'><mi>&alpha;</mi></math>

*** Output of Markdown.pl (parsed) ***
<div>
 <p>
  This is not 
  <math display='inline' xmlns='http://www.w3.org/1998/Math/MathML'>
   <mi>
    math
   </mi>
  </math>
  .
 </p>
 <math display='block' xmlns='http://www.w3.org/1998/Math/MathML'>
  <mi>
   &alpha;
  </mi>
 </math>
</div>