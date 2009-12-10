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

function fixRunIn() {
// work around lack of gecko support for display:run-in
  var re = /^num_|\s+num_|^un_|\s+un_|proof/;
  $$('div > h6').each(function(element) {
     if(re.test($(element.parentNode).className)) {
      var new_span = new Element('span').update(element.textContent);
      new_span.addClassName('theorem_label');
      var next_el = element.next().firstChild;
      next_el.parentNode.insertBefore(new_span, next_el);
      var period = new Element('span').update('. ');
      next_el.parentNode.insertBefore(period, next_el);
      element.remove();
     }
  });
// add tombstone to proof, since gecko doesn't support :last-child properly
 $$('div.proof').each(function(element) {
     var l = element.childElements().length -1;
     var span = new Element('span').update('\u00a0\u00a0\u25ae');
     element.childElements()[l].insert(span);
    });
}

function mactionWorkarounds() {
  $$('maction[actiontype="tooltip"]').each( function(mtool){
     Element.writeAttribute(mtool, 'title',
       Element.firstDescendant(mtool).nextSibling.firstChild.data);
     });
  $$('maction[actiontype="statusline"]').each( function(mstatus){
     var v = Element.firstDescendant(mstatus).nextSibling.firstChild.data;
     Event.observe(mstatus, 'mouseover', function(){window.status =  v;});
     Event.observe(mstatus, 'mouseout',  function(){window.status = '';});
     });
}

function updateSize(elt) {
   // adjust to the size of the user's browser area.
    var parentheight = document.viewport.getHeight() - $('pageName').getHeight() 
                               - $('editFormButtons').getHeight() - $('hidebutton').getHeight();
    var parentwidth = Math.min( document.viewport.getWidth(), elt.parentNode.getWidth() ) - 10 ;
    var f = $('MarkupHelp');
    if (f.visible()) {parentwidth = parentwidth - f.getWidth()}
    elt.writeAttribute({'cols': Math.floor(parentwidth/10), 'rows': Math.floor(parentheight/20)} );
    elt.setStyle({Width: parentwidth, Height: parentheight});
}

function resizeableTextarea() {
//make the textarea resize to fit available space
  var f = $('MarkupHelp');
  if (f) {
    var hidebutton = new Element('input', {id:'hidebutton', type: 'button', value: 'Hide markup help'});
    f.insert({before: hidebutton});
  }
  $$('textarea#content').each( function(textarea)  {
    Event.observe(hidebutton, 'click', function(){
      if (f.visible()) {
        f.hide();
        hidebutton.writeAttribute({value: 'Show markup help'});
        updateSize(textarea)
      } else {
        f.show();
        hidebutton.writeAttribute({value: 'Hide markup help'});  
        updateSize(textarea)    
      }
    });
    Event.observe(window, 'resize', function(){ updateSize(textarea) });
    updateSize(textarea);
   });
}

window.onload = function (){
        extractBlockquoteCitations();
        fixRunIn();
        mactionWorkarounds();
        resizeableTextarea();
};
