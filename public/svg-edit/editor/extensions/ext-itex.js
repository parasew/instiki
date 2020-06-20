var svgEditorExtension_itex = (function () {
  'use strict';

  function asyncGeneratorStep(gen, resolve, reject, _next, _throw, key, arg) {
    try {
      var info = gen[key](arg);
      var value = info.value;
    } catch (error) {
      reject(error);
      return;
    }

    if (info.done) {
      resolve(value);
    } else {
      Promise.resolve(value).then(_next, _throw);
    }
  }

  function _asyncToGenerator(fn) {
    return function () {
      var self = this,
          args = arguments;
      return new Promise(function (resolve, reject) {
        var gen = fn.apply(self, args);

        function _next(value) {
          asyncGeneratorStep(gen, resolve, reject, _next, _throw, "next", value);
        }

        function _throw(err) {
          asyncGeneratorStep(gen, resolve, reject, _next, _throw, "throw", err);
        }

        _next(undefined);
      });
    };
  }

  /**
   * ext-itex.js
   *
   * @license Apache-2.0
   *
   * @copyright 2010,2018 Jacques Distler, 2010 Alexis Deveria
   *
   */
  var extItex = {
    name: 'itex',
    init: function () {
      var _init = _asyncToGenerator(
      /*#__PURE__*/
      regeneratorRuntime.mark(function _callee2(S) {
        var svgEditor, $, NS, importLocale, svgCanvas, svgdoc, strings, properlySourceSizeTextArea, showPanel, toggleSourceButtons, selElems, started, newFO, editingitex, setItexString, showItexEditor, setAttr, buttons, contextTools;
        return regeneratorRuntime.wrap(function _callee2$(_context2) {
          while (1) {
            switch (_context2.prev = _context2.next) {
              case 0:
                setAttr = function _ref6(attr, val) {
                  svgCanvas.changeSelectedAttribute(attr, val);
                  svgCanvas.call('changed', selElems);
                };

                showItexEditor = function _ref5() {
                  var elt = selElems[0];

                  var annotation = jQuery('math > semantics > annotation', elt);
                  if (!annotation || editingitex) {
                    return;
                  }

                  editingitex = true;
                  toggleSourceButtons(true);
                  elt.removeAttribute('fill');
                  var str = annotation.text();
                  $('#svg_source_textarea').val(str);
                  $('#svg_source_editor').fadeIn();
                  properlySourceSizeTextArea();
                  $('#svg_source_textarea').focus();
                };

                setItexString = function _ref4(tex) {
                  var elt = selElems[0]; // The parent `Element` to append to

                  try {
                    var math = svgdoc.createElementNS(NS.MATH, 'math');
                    math.setAttributeNS(NS.XMLNS, 'xmlns', NS.MATH);
                    math.setAttribute('display', 'inline');
                    // make an AJAX request to the server, to get the MathML
                    var itexEndpoint = svgEditor.curConfig.itexEndpoint || '../../itex';
                    $.post(itexEndpoint, {'tex': tex, 'display': 'inline'}, function(data){
                    var first = data.documentElement.firstElementChild;
                    // If itex2MML included the original tex source as an <annotation>,
                    // then we don't have to. Otherwise, let's do that ourselves.
                    if (first.localName == 'semantics') {
                      math.appendChild(svgdoc.adoptNode(first, true));
                    } else {
                      var semantics = document.createElementNS(NS.MATH, 'semantics');
                      var annotation = document.createElementNS(NS.MATH, 'annotation');
                      annotation.setAttribute('encoding', 'application/x-tex');
                      annotation.textContent = tex;
                      var mrow = document.createElementNS(NS.MATH, 'mrow');
                      semantics.appendChild(mrow);
                      semantics.appendChild(annotation);
                      math.appendChild(semantics);
                      var children = data.documentElement.childNodes;
                      while (children.length > 0) {
                        mrow.appendChild(svgdoc.adoptNode(children[0], true));
                      }
                    }
                    svgCanvas.sanitizeSvg(math);
                    svgCanvas.call("changed", [elt]);
                });
                elt.replaceChild(math, elt.firstChild);
                svgCanvas.call("changed", [elt]);
                svgCanvas.clearSelection();
              } catch(e) {
                console.log(e);
                return false;
              }

                  return true;
                };

                toggleSourceButtons = function _ref3(on) {
                  $('#tool_source_save, #tool_source_cancel').toggle(!on);
                  $('#itex_save, #itex_cancel').toggle(on);
                };

                showPanel = function _ref2(on) {
                  var fcRules = $('#fc_rules');

                  if (!fcRules.length) {
                    fcRules = $('<style id="fc_rules"></style>').appendTo('head');
                  }

                  fcRules.text(!on ? '' : ' #tool_topath { display: none !important; }');
                  $('#itex_panel').toggle(on);
                };

                svgEditor = this;
                $ = S.$, NS = S.NS, importLocale = S.importLocale;
                svgCanvas = svgEditor.canvas;
                svgdoc = S.svgroot.parentNode.ownerDocument;
                _context2.next = 11;
                return importLocale();

              case 11:
                strings = _context2.sent;

                properlySourceSizeTextArea = function properlySourceSizeTextArea() {
                  // TODO: remove magic numbers here and get values from CSS
                  var height = $('#svg_source_container').height() - 80;
                  $('#svg_source_textarea').css('height', height);
                };
                /**
                * @param {boolean} on
                * @returns {undefined}
                */


                editingitex = false;
                /**
                * This function sets the content of element elt to the input XML.
                * @param {string} xmlString - The XML text
                * @returns {boolean} This function returns false if the set was unsuccessful, true otherwise.
                */

                buttons = [{
                  id: 'tool_itex',
                  icon: svgEditor.curConfig.extIconsPath + 'itex-tool.png',
                  type: 'mode',
                  events: {
                    click: function click() {
                      svgCanvas.setMode('itex');
                    }
                  }
                }, {
                  id: 'edit_itex',
                  icon: svgEditor.curConfig.extIconsPath + 'itex-edit.png',
                  type: 'context',
                  panel: 'itex_panel',
                  events: {
                    click: function click() {
                      showItexEditor();
                    }
                  }
                }];
                contextTools = [{
                  type: 'input',
                  panel: 'itex_panel',
                  id: 'itex_width',
                  size: 3,
                  events: {
                    change: function change() {
                      setAttr('width', this.value);
                    }
                  }
                }, {
                  type: 'input',
                  panel: 'itex_panel',
                  id: 'itex_height',
                  events: {
                    change: function change() {
                      setAttr('height', this.value);
                    }
                  }
                }, {
                  type: 'input',
                  panel: 'itex_panel',
                  id: 'itex_font_size',
                  size: 2,
                  defval: 16,
                  events: {
                    change: function change() {
                      setAttr('font-size', this.value);
                    }
                  }
                }];
                return _context2.abrupt("return", {
                  name: strings.name,
                  svgicons: svgEditor.curConfig.extIconsPath + 'itex-icons.xml',
                  buttons: strings.buttons.map(function (button, i) {
                    return Object.assign(buttons[i], button);
                  }),
                  context_tools: strings.contextTools.map(function (contextTool, i) {
                    return Object.assign(contextTools[i], contextTool);
                  }),
                  callback: function callback() {
                    $('#itex_panel').hide();

                    var endChanges = function endChanges() {
                      $('#svg_source_editor').hide();
                      editingitex = false;
                      $('#svg_source_textarea').blur();
                      toggleSourceButtons(false);
                    }; // TODO: Needs to be done after orig icon loads


                    setTimeout(function () {
                      // Create source save/cancel buttons

                      /* const save = */
                      $('#tool_source_save').clone().hide().attr('id', 'itex_save').unbind().appendTo('#tool_source_back').click(
                      /*#__PURE__*/
                      _asyncToGenerator(
                      /*#__PURE__*/
                      regeneratorRuntime.mark(function _callee() {
                        var ok;
                        return regeneratorRuntime.wrap(function _callee$(_context) {
                          while (1) {
                            switch (_context.prev = _context.next) {
                              case 0:
                                if (editingitex) {
                                  _context.next = 2;
                                  break;
                                }

                                return _context.abrupt("return");

                              case 2:
                                if (setItexString($('#svg_source_textarea').val())) {
                                  _context.next = 11;
                                  break;
                                }

                                _context.next = 5;
                                return $.confirm('Errors found. Revert to original?');

                              case 5:
                                ok = _context.sent;

                                if (ok) {
                                  _context.next = 8;
                                  break;
                                }

                                return _context.abrupt("return");

                              case 8:
                                endChanges();
                                _context.next = 12;
                                break;

                              case 11:
                                endChanges();

                              case 12:
                              case "end":
                                return _context.stop();
                            }
                          }
                        }, _callee, this);
                      })));
                      /* const cancel = */

                      $('#tool_source_cancel').clone().hide().attr('id', 'itex_cancel').unbind().appendTo('#tool_source_back').click(function () {
                        endChanges();
                      });
                    }, 3000);
                  },
                  mouseDown: function mouseDown(opts) {
                    // const e = opts.event;
                    if (svgCanvas.getMode() !== 'itex') {
                      return undefined;
                    }

                    started = true;
                    newFO = svgCanvas.addSVGElementFromJson({
                      element: 'foreignObject',
                      attr: {
                        x: opts.start_x,
                        y: opts.start_y,
                        id: svgCanvas.getNextId(),
                        'font-size': 16,
                        // cur_text.font_size,
                        width: '48',
                        height: '22',
                        style: 'pointer-events:inherit'
                      }
                    });
                    var m = svgdoc.createElementNS(NS.MATH, 'math');
                    m.setAttributeNS(NS.XMLNS, 'xmlns', NS.MATH);
                    m.setAttribute('display', 'inline');
                    var semantics = svgdoc.createElementNS(NS.MATH, 'semantics');
                    var mrow = svgdoc.createElementNS(NS.MATH, 'mrow');
                    var mi = svgdoc.createElementNS(NS.MATH, 'mi');
                    mi.setAttribute('mathvariant', 'normal');
                    mi.textContent = "\u03A6";
                    var mo = svgdoc.createElementNS(NS.MATH, 'mo');
                    mo.textContent = "\u222A";
                    var mi2 = svgdoc.createElementNS(NS.MATH, 'mi');
                    mi2.textContent = "\u2133";
                    var annotation = svgdoc.createElementNS(NS.MATH, 'annotation');
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
                    };
                  },
                  mouseUp: function mouseUp(opts) {
                    // const e = opts.event;
                    if (svgCanvas.getMode() !== 'itex' || !started) {
                      return undefined;
                    }

                    var attrs = $(newFO).attr(['width', 'height']);
                    var keep = attrs.width !== '0' || attrs.height !== '0';
                    svgCanvas.addToSelection([newFO], true);
                    return {
                      keep: keep,
                      element: newFO
                    };
                  },
                  selectedChanged: function selectedChanged(opts) {
                    // Use this to update the current selected elements
                    selElems = opts.elems;
                    var i = selElems.length;

                    while (i--) {
                      var elem = selElems[i];

                      if (elem && elem.tagName === 'foreignObject') {
                        if(opts.selectedElement && !opts.multiselected &&
                          elem.firstElementChild.namespaceURI == NS.MATH ) {
                          $('#itex_font_size').val(elem.getAttribute('font-size'));
                          $('#itex_width').val(elem.getAttribute('width'));
                          $('#itex_height').val(elem.getAttribute('height'));
                          showPanel(true);
                        } else {
                          showPanel(false);
                        }
                      } else {
                        showPanel(false);
                      }
                    }
                  },
                  elementChanged: function elementChanged(opts) {}
                });

              case 17:
              case "end":
                return _context2.stop();
            }
          }
        }, _callee2, this);
      }));

      function init(_x) {
        return _init.apply(this, arguments);
      }

      return init;
    }()
  };

  return extItex;

}());

