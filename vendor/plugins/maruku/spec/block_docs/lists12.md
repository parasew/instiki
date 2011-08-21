List Items with non alphanumeric content
*** Parameters: ***
{}
*** Markdown input: ***
* A
* ?
* B

*** Output of inspect ***
md_el(:document,[
  md_el(:ul,[
    md_el(:li_span,["A"],{:want_my_paragraph=>false},[]),
    md_el(:li_span,["?"],{:want_my_paragraph=>false},[]),
    md_el(:li_span,["B"],{:want_my_paragraph=>false},[])
  ],{},[])
],{},[])

*** Output of to_html ***
<ul>
<li>A</li>

<li>?</li>

<li>B</li>
</ul>

*** Output of to_latex ***
\begin{itemize}%
\item A
\item ?
\item B

\end{itemize}

*** Output of to_md ***
- A
- ?
- B

*** Output of to_s ***
A?B


