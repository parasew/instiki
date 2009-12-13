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

function updateSize(elt, w, h) {
   // adjust to the size of the user's browser area.
   // w and h are the original, unadjusted, width and height per row/column
    var parentheight = document.viewport.getHeight() - $('pageName').getHeight() 
                  - $('editFormButtons').getHeight() - $('hidebutton').getHeight();
    var parentwidth = $('Content').getWidth();
    var f = $('MarkupHelp');
    if (f.visible()) { parentwidth = parentwidth - f.getWidth() - 20 }
    var changename = $('alter_title');
    if (changename) {
      parentheight = parentheight - changename.parentNode.getHeight()-2*h;
    }
    elt.writeAttribute({'cols': Math.floor(parentwidth/w)  - 1,
                        'rows': Math.floor(parentheight/h) - 4 });
    elt.setStyle({Width: parentwidth, Height: parentheight});
}

function resizeableTextarea() {
//make the textarea resize to fit available space
  var f = $('MarkupHelp');
  if (f) {
    var hidebutton = new Element('input', {id:'hidebutton', type:'button', value: 'Hide markup help'});
    f.insert({before: hidebutton});
  }
  $$('textarea#content').each( function(textarea)  {
    var w = textarea.getWidth()/textarea.getAttribute('cols');
    var h = textarea.getStyle('lineHeight').replace(/(\d*)px/, "$1");
    var changename = $('alter_title');
    if (changename) {
      Event.observe(changename.parentNode, 'change', function() {
        updateSize(textarea, w, h);
      });
    }
    Event.observe(hidebutton, 'click', function(){
      if (f.visible()) {
        f.hide();
        hidebutton.writeAttribute({value: 'Show markup help'});
        updateSize(textarea, w, h)
      } else {
        f.show();
        hidebutton.writeAttribute({value: 'Hide markup help'});  
        updateSize(textarea, w, h)    
      }
    });
    Event.observe(window, 'resize', function(){ updateSize(textarea, w, h) });
    updateSize(textarea, w, h);
   });
}

window.onload = function (){
        extractBlockquoteCitations();
        fixRunIn();
        mactionWorkarounds();
        resizeableTextarea();
};
