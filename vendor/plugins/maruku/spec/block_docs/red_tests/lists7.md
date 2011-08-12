I'm not sure if this should work at all...

*** Parameters: ***
{} # params 
*** Markdown input: ***
Ciao

*	Tab
	*	Tab
		*	Tab

*** Output of inspect ***
nil
*** Output of to_html ***
<p>Ciao</p>

<ul>
<li>Tab * Tab * Tab</li>
</ul>
*** Output of to_latex ***
Ciao

\begin{itemize}%
\item Tab * Tab * Tab

\end{itemize}
*** Output of to_md ***
Ciao

-ab * Tab * Tab
*** Output of to_s ***
CiaoTab * Tab * Tab
