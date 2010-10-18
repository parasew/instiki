MathJax.Hub.Config({
  config: ["MMLorHTML.js"],
  jax: ["input/MathML"],
  extensions: ["mml2jax.js"],
  MathML: {
    useMathMLspacing: true
  },
  "HTML-CSS": {
    preferredFont: "STIX",
    scale: 90
  },
  MMLorHTML: {
    //
    //  The output jax that is to be preferred when both are possible
    //  (set to "MML" for native MathML, "HTML" for MathJax's HTML-CSS output jax).
    //
    prefer:
    {
      MSIE:    "MML",
      Firefox: "MML",
      Opera:   "HTML",
      other:   "HTML"
    }
  }
});

MathJax.Hub.Startup.onload();
MathJax.Ajax.loadComplete("[MathJax]/config/MathJax.js");
