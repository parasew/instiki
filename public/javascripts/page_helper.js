/*
* Based on Simon Willison's blockquotes.js
*   http://simon.incutio.com/archive/2002/12/20/#blockquoteCitations
*/
function extractBlockquoteCitations() {
  var quotes = document.getElementsByTagName('blockquote');
  for (i = 0; i < quotes.length; i++) {
    var cite = quotes[i].getAttribute('cite');
    if (cite && cite != '') {
      var newlink = document.createElement('a');
      newlink.setAttribute('href', cite);
      newlink.setAttribute('title', cite);
      newlink.appendChild(document.createTextNode('#'));
      var newspan = document.createElement('span');
      newspan.setAttribute('class','blockquotesource');
      newspan.appendChild(newlink);
      quotes[i].lastChild.previousSibling.appendChild(newspan);
    }
  }
}
window.onload = function (){
        extractBlockquoteCitations();
};
