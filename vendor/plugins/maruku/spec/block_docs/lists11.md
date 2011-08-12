Write a comment here
*** Parameters: ***
{} # params 
*** Markdown input: ***
- ένα

*** Output of inspect ***
md_el(:document,[
	md_el(:ul,[md_el(:li_span,["ένα"],{:want_my_paragraph=>false},[])],{},[])
],{},[])
*** Output of to_html ***
<ul>
<li>&#x3AD;&#x3BD;&#x3B1;</li>
</ul>
*** Output of to_latex ***
\begin{itemize}%
\item ένα

\end{itemize}
*** Output of to_md ***
- ένα
*** Output of to_s ***
ένα
