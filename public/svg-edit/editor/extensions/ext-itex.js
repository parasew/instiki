/*
 * ext-itex.js
 *
 * Licensed under the Apache License, Version 2
 *
 * Copyright(c) 2010 Jacques Distler 
 * Copyright(c) 2010 Alexis Deveria 
 *
 */

svgEditor.addExtension("itex", function(S) {
		var svgcontent = S.svgcontent,
			addElem = S.addSvgElementFromJson,
			selElems,
			svgns = "http://www.w3.org/2000/svg",
			xlinkns = "http://www.w3.org/1999/xlink",
			xmlns = "http://www.w3.org/XML/1998/namespace",
			xmlnsns = "http://www.w3.org/2000/xmlns/",
			se_ns = "http://svg-edit.googlecode.com",
			htmlns = "http://www.w3.org/1999/xhtml",
			mathns = "http://www.w3.org/1998/Math/MathML",
			ajaxEndpoint = "../../itex",
			editingitex = false,
			svgdoc = S.svgroot.parentNode.ownerDocument,
			started,
			newFO;
			
			
		var properlySourceSizeTextArea = function(){
			// TODO: remove magic numbers here and get values from CSS
			var height = $('#svg_source_container').height() - 80;
			$('#svg_source_textarea').css('height', height);
		};

		function showPanel(on) {
			var fc_rules = $('#fc_rules');
			if(!fc_rules.length) {
				fc_rules = $('<style id="fc_rules"><\/style>').appendTo('head');
			} 
			fc_rules.text(!on?"":" #tool_topath { display: none !important; }");
			$('#itex_panel').toggle(on);
		}

		function toggleSourceButtons(on) {
			$('#tool_source_save, #tool_source_cancel').toggle(!on);
			$('#itex_save, #itex_cancel').toggle(on);
		}
		
		// Function: setItexString(string, url)
		// This function sets the content of of the currently-selected foreignObject element,
		// based on the itex contained in string.
		//
		// Parameters:
		// string - The itex text.
		// url - the url of the itex server to do the conversion
		//
		// Returns:
		// This function returns false if the set was unsuccessful, true otherwise.
		function setItexString(tex) {
			var elt = selElems[0];
			try {
				var math = svgdoc.createElementNS(mathns, 'math');
				math.setAttributeNS(xmlnsns, 'xmlns', mathns);
				math.setAttribute('display', 'inline');
				var semantics = document.createElementNS(mathns, 'semantics');
				var annotation = document.createElementNS(mathns, 'annotation');
				annotation.setAttribute('encoding', 'application/x-tex');
				annotation.textContent = tex;
				var mrow = document.createElementNS(mathns, 'mrow');
				semantics.appendChild(mrow);
				semantics.appendChild(annotation);
				math.appendChild(semantics);
				// make an AJAX request to the server, to get the MathML
				$.post(ajaxEndpoint, {'tex': tex, 'display': 'inline'}, function(data){
				    var children = data.documentElement.childNodes;
				    while (children.length > 0) {
				      mrow.appendChild(svgdoc.adoptNode(children[0], true));
				    }
				    S.sanitizeSvg(math);
				    S.call("changed", [elt]);
				});
				elt.replaceChild(math, elt.firstChild);
				S.call("changed", [elt]);
				svgCanvas.clearSelection();
			} catch(e) {
				console.log(e);
				return false;
			}
	
			return true;
		};

		function showItexEditor() {
			var elt = selElems[0];
			var annotation = jQuery('math > semantics > annotation', elt);
			if (!annotation || editingitex) return;
			editingitex = true;
			toggleSourceButtons(true);
			// elt.removeAttribute('fill');

			var str = annotation.text();
			$('#svg_source_textarea').val(str);
			$('#svg_source_editor').fadeIn();
			properlySourceSizeTextArea();
			$('#svg_source_textarea').focus();
		}
		
		function setAttr(attr, val) {
			svgCanvas.changeSelectedAttribute(attr, val);
			S.call("changed", selElems);
		}
		
		
		return {
			name: "itex",
			svgicons: "extensions/itex-icons.xml",
			buttons: [{
				id: "tool_itex",
				type: "mode",
				title: "itex Tool",
				events: {
					'click': function() {
						svgCanvas.setMode('itex')
					}
				}
			},{
				id: "edit_itex",
				type: "context",
				panel: "itex_panel",
				title: "Edit TeX Content",
				events: {
					'click': function() {
						showItexEditor();
					}
				}
			}],
			
			context_tools: [{
				type: "input",
				panel: "itex_panel",
				title: "Change enclosing foreignObject's width",
				id: "itex_width",
				label: "w",
				size: 3,
				events: {
					change: function() {
						setAttr('width', this.value);
					}
				}
			},{
				type: "input",
				panel: "itex_panel",
				title: "Change enclosing foreignObject's height",
				id: "itex_height",
				label: "h",
				events: {
					change: function() {
						setAttr('height', this.value);
					}
				}
			}, {
				type: "input",
				panel: "itex_panel",
				title: "Change font size",
				id: "itex_font_size",
				label: "font-size",
				size: 2,
				defval: 16,
				events: {
					change: function() {
						setAttr('font-size', this.value);
					}
				}
			}
			
			
			],
			callback: function() {
				$('#itex_panel').hide();

				var endChanges = function() {
					$('#svg_source_editor').hide();
					editingitex = false;
					$('#svg_source_textarea').blur();
					toggleSourceButtons(false);
				}

				// TODO: Needs to be done after orig icon loads
				setTimeout(function() {				
					// Create source save/cancel buttons
					var save = $('#tool_source_save').clone()
						.hide().attr('id', 'itex_save').unbind()
						.appendTo("#tool_source_back").click(function() {
							
							if (!editingitex) return;

							if (!setItexString($('#svg_source_textarea').val())) {
								$.confirm("Errors found. Revert to original?", function(ok) {
									if(!ok) return false;
									endChanges();
								});
							} else {
								endChanges();
							}
							// setSelectMode();	
						});
						
					var cancel = $('#tool_source_cancel').clone()
						.hide().attr('id', 'itex_cancel').unbind()
						.appendTo("#tool_source_back").click(function() {
							endChanges();
						});
					
				}, 3000);
			},
			mouseDown: function(opts) {
				var e = opts.event;
				
				if(svgCanvas.getMode() == "itex") {

					started = true;
					newFO = S.addSvgElementFromJson({
						"element": "foreignObject",
						"attr": {
							"x": opts.start_x,
							"y": opts.start_y,
							"id": S.getNextId(),
							"font-size": 16, //cur_text.font_size,
							"width": "48",
							"height": "20",
							"style": "pointer-events:inherit"
						}
					});
					var m = svgdoc.createElementNS(mathns, 'math');
					m.setAttributeNS(xmlnsns, 'xmlns', mathns);
					m.setAttribute('display', 'inline');
					var semantics = svgdoc.createElementNS(mathns, 'semantics');
					var mrow = svgdoc.createElementNS(mathns, 'mrow');
					var mi = svgdoc.createElementNS(mathns, 'mi');
					mi.setAttribute('mathvariant', 'normal');
					mi.textContent = "\u03A6";
					var mo = svgdoc.createElementNS(mathns, 'mo');
					mo.textContent = "\u222A";
					var mi2 = svgdoc.createElementNS(mathns, 'mi');
					mi2.textContent = "\u2133";
					var annotation = svgdoc.createElementNS(mathns, 'annotation');
					annotation.setAttribute('encoding', 'application/x-tex');
					annotation.textContent = "\\Phi \\union \\mathcal{M}";
					mrow.appendChild(mi);
					mrow.appendChild(mo);
					mrow.appendChild(mi2);
					semantics.appendChild(mrow);
					semantics.appendChild(annotation);
					m.appendChild(semantics);
					newFO.appendChild(m);
					return {
						started: true
					}
				}
			},
			mouseUp: function(opts) {
				var e = opts.event;				
				if(svgCanvas.getMode() == "itex" && started) {
					var attrs = $(newFO).attr(["width", "height"]);
					keep = (attrs.width != 0 || attrs.height != 0);					
					svgCanvas.addToSelection([newFO], true);

					return {
						keep: keep,
						element: newFO
					}

				}
				
			},
			selectedChanged: function(opts) {
				// Use this to update the current selected elements
				selElems = opts.elems;
				
				var i = selElems.length;
				
				while(i--) {
					var elem = selElems[i];
					if(elem && elem.tagName == "foreignObject") {
						if(opts.selectedElement && !opts.multiselected &&
							  elem.firstElementChild.namespaceURI == mathns ) {
							$('#itex_font_size').val(elem.getAttribute("font-size"));
							$('#itex_width').val(elem.getAttribute("width"));
							$('#itex_height').val(elem.getAttribute("height"));
						
							showPanel(true);
						} else {
							showPanel(false);
						}
					} else {
						showPanel(false);
					}
				}
			},
			elementChanged: function(opts) {
				var elem = opts.elems[0];
			}
		};
});
