Write a comment abouth the test here.
*** Parameters: ***
{:title=>"header"}
*** Markdown input: ***
Paragraph
### header ###

Paragraph
header
------

Paragraph
header
======

*** Output of inspect ***
md_el(:document,[
	md_par(["Paragraph"]),
	md_el(:header,["header"],{:level=>3},[]),
	md_par(["Paragraph"]),
	md_el(:header,["header"],{:level=>2},[]),
	md_par(["Paragraph"]),
	md_el(:header,["header"],{:level=>1},[])
],{},[])
*** Output of to_html ***
<p>Paragraph</p>

<h3 id="header_1">header</h3>

<p>Paragraph</p>

<h2 id="header_2">header</h2>

<p>Paragraph</p>

<h1 id="header_3">header</h1>
*** Output of to_latex ***
Paragraph

\hypertarget{header_1}{}\subsubsection*{{header}}\label{header_1}

Paragraph

\hypertarget{header_2}{}\subsection*{{header}}\label{header_2}

Paragraph

\hypertarget{header_3}{}\section*{{header}}\label{header_3}
*** Output of to_md ***
Paragraph

headerParagraph

headerParagraph

header
*** Output of to_s ***
ParagraphheaderParagraphheaderParagraphheader
