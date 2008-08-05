
*** Parameters: ***
require 'maruku/ext/math'
{:math_numbered => ['\\['], :html_math_engine => 'itex2mml' }
*** Markdown input: ***

\[
	\alpha
\]

\begin{equation}
	\alpha
\end{equation}

\begin{equation} \beta
\end{equation}


\begin{equation} \gamma \end{equation}
*** Output of inspect ***
md_el(:document,[
	md_el(:equation,[],{:label=>"eq1",:math=>"\t\\alpha\n\n",:num=>1},[]),
	md_el(:equation,[],{:label=>nil,:math=>"\t\\alpha\n\n",:num=>nil},[]),
	md_el(:equation,[],{:label=>nil,:math=>" \\beta\n",:num=>nil},[]),
	md_el(:equation,[],{:label=>nil,:math=>" \\gamma ",:num=>nil},[])
],{},[])
*** Output of to_html ***
<div class='maruku-equation' id='eq:eq1'><span class='maruku-eq-number'>(1)</span><math class='maruku-mathml' display='block' xmlns='http://www.w3.org/1998/Math/MathML'><mi>&alpha;</mi></math><div class='maruku-eq-tex'><code style='display: none'>	\alpha

</code></div></div><div class='maruku-equation'><math class='maruku-mathml' display='block' xmlns='http://www.w3.org/1998/Math/MathML'><mi>&alpha;</mi></math><div class='maruku-eq-tex'><code style='display: none'>	\alpha

</code></div></div><div class='maruku-equation'><math class='maruku-mathml' display='block' xmlns='http://www.w3.org/1998/Math/MathML'><mi>&beta;</mi></math><div class='maruku-eq-tex'><code style='display: none'> \beta
</code></div></div><div class='maruku-equation'><math class='maruku-mathml' display='block' xmlns='http://www.w3.org/1998/Math/MathML'><mi>&gamma;</mi></math><div class='maruku-eq-tex'><code style='display: none'> \gamma </code></div></div>
*** Output of to_latex ***
\begin{equation}
\alpha
\label{eq1}\end{equation}
\begin{displaymath}
\alpha
\end{displaymath}
\begin{displaymath}
\beta
\end{displaymath}
\begin{displaymath}
\gamma
\end{displaymath}
*** Output of to_md ***

*** Output of to_s ***

*** EOF ***




Failed tests:   [:to_html] 

*** Output of inspect ***
md_el(:document,[
	md_el(:equation,[],{:label=>"eq1",:math=>"\t\\alpha\n\n",:num=>1},[]),
	md_el(:equation,[],{:label=>nil,:math=>"\t\\alpha\n\n",:num=>nil},[]),
	md_el(:equation,[],{:label=>nil,:math=>" \\beta\n",:num=>nil},[]),
	md_el(:equation,[],{:label=>nil,:math=>" \\gamma ",:num=>nil},[])
],{},[])
*** Output of to_html ***
-----| WARNING | -----
<div class='maruku-equation' id='eq:eq1'><span class='maruku-eq-number'>(1)</span><code class='maruku-mathml'>	\alpha

</code><div class='maruku-eq-tex'><code style='display: none'>	\alpha

</code></div></div><div class='maruku-equation'><code class='maruku-mathml'>	\alpha

</code><div class='maruku-eq-tex'><code style='display: none'>	\alpha

</code></div></div><div class='maruku-equation'><code class='maruku-mathml'> \beta
</code><div class='maruku-eq-tex'><code style='display: none'> \beta
</code></div></div><div class='maruku-equation'><code class='maruku-mathml'> \gamma </code><div class='maruku-eq-tex'><code style='display: none'> \gamma </code></div></div>
*** Output of to_latex ***
\begin{equation}
\alpha
\label{eq1}\end{equation}
\begin{displaymath}
\alpha
\end{displaymath}
\begin{displaymath}
\beta
\end{displaymath}
\begin{displaymath}
\gamma
\end{displaymath}
*** Output of to_md ***

*** Output of to_s ***

*** Output of Markdown.pl ***
(not used anymore)
*** Output of Markdown.pl (parsed) ***
(not used anymore)