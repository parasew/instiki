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

function addS5button(page_name) {
  var f = $('MarkupHelp');
  if (f) {
    var s5button = new Element('input', {id:'S5button', type:'button', value: 'Make this page an S5 slideshow'});
    f.insert({top: s5button});
    Event.observe(s5button, 'click', function(){
      var preamble = "author: " + document.getElementById('author').value +
        "\ncompany: \ntitle: " + page_name +
        "\nsubtitle: \nslide_theme: default\nslide_footer: \nslide_subfooter: " +
        "\n\n:category: S5-slideshow\n\n" + page_name +
        "\n==============\n\nMy First Slide\n-----------------\n\n";
      var content = document.getElementById('content');
      content.value = preamble + content.value;
      document.getElementById('S5button').hide();
    });
  }
}

function setupSVGedit(path){
  var f = $('MarkupHelp');
  var selected;
  var before;
  var after;
// create a control button
  if (f) {
    var SVGeditButton = new Element('input', {id:'SVGeditButton', type:'button', value: 'Create an SVG graphic'});
    f.insert({top: SVGeditButton});
    SVGeditButton.disabled = true;
    Event.observe(SVGeditButton, 'click', function(){
      var editor = window.open(path + "?initStroke[width]=2", 'Edit SVG graphic', 'status=1,resizable=1,scrollbars=1');
      editor.addEventListener("load", function() {
        editor.svgEditor.setCustomHandlers({
            'save': function(window,svg){
               editor.svgEditor.setConfig({no_save_warning: true});
               window.opener.postMessage(svg, window.location.protocol + '//' + window.location.host);
               window.close();
            }
        });
        editor.svgEditor.randomizeIds();
        if (selected) editor.svgEditor.loadFromString(selected);
      }, true);
      SVGeditButton.disabled = true;
      SVGeditButton.value = 'Create SVG graphic';      
      editor.focus();
    });
  }   
  var t = $('content');
  
  var callback = function(){
// This is triggered by 'onmouseup' events
    var sel = window.getSelection();
    var a = sel.anchorOffset;
    var f = sel.focusOffset;
// A bit of ugliness, because Gecko-based browsers
// don't support getSelection in textareas
    if (t.selectionStart ) {
      var begin = t.selectionStart;
      var end = t.selectionEnd;
    } else {
      if( a < f) {
        begin = a;
        end = f;
      } else {
        begin = f;
        end = a;
      }
    }
// finally, slice up the textarea content into before, selected, & after pieces
    before = t.value.slice(0, begin);
    selected = t.value.slice(begin, end);
    after = t.value.slice(end, t.value.length);
    if (selected && selected != '') {
      if ( selected.match(/^<svg(.|\n)*<\/svg>$/) && !selected.match(/<\/svg>(.|\n)/)) {
        SVGeditButton.disabled = false;
        SVGeditButton.value = 'Edit existing SVG graphic';
      } else {
        SVGeditButton.disabled = true;
      }
    } else {
      SVGeditButton.disabled = false;
      SVGeditButton.value = 'Create SVG graphic';      
    }
  }
  Event.observe(t, 'mouseup', callback );
  var my_loc = window.location.protocol + '//' + window.location.host;
  Event.observe(window, "message", function(event){
    if(event.origin !== my_loc) { return;}
    t.value = before + event.data + after;
    t.focus();
    selectRange(t, before.length, before.length+event.data.length);
    callback();      
  });  
}

function selectRange(elt, start, end) { 
 if (elt.setSelectionRange) { 
  elt.focus(); 
  elt.setSelectionRange(start, end); 
 } else if (elt.createTextRange) { 
  var range = elt.createTextRange(); 
  range.collapse(true); 
  range.moveEnd('character', end); 
  range.moveStart('character', start); 
  range.select(); 
 } 
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
