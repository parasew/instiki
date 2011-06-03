MathJax.Hub.Config({
  config: ["MMLorHTML.js"],
  jax: ["input/MathML"],
  extensions: ["mml2jax.js","MathMenu.js","MathZoom.js"],
  MathML: {
    useMathMLspacing: true
  },
  "HTML-CSS": {
    preferredFont: "STIX",
    scale: 90
  },
  MMLorHTML: {
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
MathJax.Ajax.loadComplete("[MathJax]/config/local/local.js");
