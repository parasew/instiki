Write a comment here
*** Parameters: ***
{} # params 
*** Markdown input: ***
[test][]:

*** Output of inspect ***
md_el(:document,[md_par([md_link(["test"],"test"), ":"])],{},[])
*** Output of to_html ***
<p><span>test</span>:</p>
*** Output of to_latex ***
test:
*** Output of to_md ***
[test][]:
*** Output of to_s ***
test:
