module Sanitize

# This module provides sanitization of XHTML+MathML+SVG
# and of inline style attributes.
#
# Based heavily on Sam Ruby's code in the Universal FeedParser.

  require 'html/tokenizer'
  require 'node'

  acceptable_elements = ['a', 'abbr', 'acronym', 'address', 'area', 'b',
      'big', 'blockquote', 'br', 'button', 'caption', 'center', 'cite',
      'code', 'col', 'colgroup', 'dd', 'del', 'dfn', 'dir', 'div', 'dl', 'dt',
      'em', 'fieldset', 'font', 'form', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
      'hr', 'i', 'img', 'input', 'ins', 'kbd', 'label', 'legend', 'li', 'map',
      'menu', 'ol', 'optgroup', 'option', 'p', 'pre', 'q', 's', 'samp',
      'select', 'small', 'span', 'strike', 'strong', 'sub', 'sup', 'table',
      'tbody', 'td', 'textarea', 'tfoot', 'th', 'thead', 'tr', 'tt', 'u',
      'ul', 'var']
      
  mathml_elements = ['maction', 'math', 'merror', 'mfrac', 'mi',
      'mmultiscripts', 'mn', 'mo', 'mover', 'mpadded', 'mphantom',
      'mprescripts', 'mroot', 'mrow', 'mspace', 'msqrt', 'mstyle', 'msub',
      'msubsup', 'msup', 'mtable', 'mtd', 'mtext', 'mtr', 'munder',
      'munderover', 'none']
      
  svg_elements = ['a', 'animate', 'animateColor', 'animateMotion',
      'animateTransform', 'circle', 'defs', 'desc', 'ellipse', 'font-face',
      'font-face-name', 'font-face-src', 'g', 'glyph', 'hkern', 'image',
      'linearGradient', 'line', 'marker', 'metadata', 'missing-glyph',
      'mpath', 'path', 'polygon', 'polyline', 'radialGradient', 'rect',
      'set', 'stop', 'svg', 'switch', 'text', 'title', 'tspan', 'use']
      
  acceptable_attributes = ['abbr', 'accept', 'accept-charset', 'accesskey',
      'action', 'align', 'alt', 'axis', 'border', 'cellpadding',
      'cellspacing', 'char', 'charoff', 'charset', 'checked', 'cite', 'class',
      'clear', 'cols', 'colspan', 'color', 'compact', 'coords', 'datetime',
      'dir', 'disabled', 'enctype', 'for', 'frame', 'headers', 'height',
      'href', 'hreflang', 'hspace', 'id', 'ismap', 'label', 'lang',
      'longdesc', 'maxlength', 'media', 'method', 'multiple', 'name',
      'nohref', 'noshade', 'nowrap', 'prompt', 'readonly', 'rel', 'rev',
      'rows', 'rowspan', 'rules', 'scope', 'selected', 'shape', 'size',
      'span', 'src', 'start', 'style', 'summary', 'tabindex', 'target', 'title',
      'type', 'usemap', 'valign', 'value', 'vspace', 'width', 'xml:lang']


  mathml_attributes = ['actiontype', 'align', 'columnalign', 'columnalign',
      'columnalign', 'columnlines', 'columnspacing', 'columnspan', 'depth',
      'display', 'displaystyle', 'equalcolumns', 'equalrows', 'fence',
      'fontstyle', 'fontweight', 'frame', 'height', 'linethickness', 'lspace',
      'mathbackground', 'mathcolor', 'mathvariant', 'mathvariant', 'maxsize',
      'minsize', 'other', 'rowalign', 'rowalign', 'rowalign', 'rowlines',
      'rowspacing', 'rowspan', 'rspace', 'scriptlevel', 'selection',
      'separator', 'stretchy', 'width', 'width', 'xlink:href', 'xlink:show',
      'xlink:type', 'xmlns', 'xmlns:xlink']

      
  svg_attributes = ['accent-height', 'accumulate', 'additive', 'alphabetic',
       'arabic-form', 'ascent', 'attributeName', 'attributeType',
       'baseProfile', 'bbox', 'begin', 'by', 'calcMode', 'cap-height',
       'class', 'color', 'color-rendering', 'content', 'cx', 'cy', 'd', 'dx',
       'dy', 'descent', 'display', 'dur', 'end', 'fill', 'fill-rule',
       'font-family', 'font-size', 'font-stretch', 'font-style', 'font-variant',
       'font-weight', 'from', 'fx', 'fy', 'g1', 'g2', 'glyph-name', 
       'gradientUnits', 'hanging', 'height', 'horiz-adv-x', 'horiz-origin-x',
       'id', 'ideographic', 'k', 'keyPoints', 'keySplines', 'keyTimes',
       'lang', 'marker-end', 'marker-mid', 'marker-start', 'markerHeight',
       'markerUnits', 'markerWidth', 'mathematical', 'max', 'min', 'name',
       'offset', 'opacity', 'orient', 'origin', 'overline-position',
       'overline-thickness', 'panose-1', 'path', 'pathLength', 'points',
       'preserveAspectRatio', 'r', 'refX', 'refY', 'repeatCount', 'repeatDur',
       'requiredExtensions', 'requiredFeatures', 'restart', 'rotate', 'rx',
       'ry', 'slope', 'stemh', 'stemv', 'stop-color', 'stop-opacity',
       'strikethrough-position', 'strikethrough-thickness', 'stroke',
       'stroke-dasharray', 'stroke-dashoffset', 'stroke-linecap',
       'stroke-linejoin', 'stroke-miterlimit', 'stroke-opacity',
       'stroke-width', 'systemLanguage', 'target',
       'text-anchor', 'to', 'transform', 'type', 'u1', 'u2',
       'underline-position', 'underline-thickness', 'unicode',
       'unicode-range', 'units-per-em', 'values', 'version', 'viewBox',
       'visibility', 'width', 'widths', 'x', 'x-height', 'x1', 'x2',
       'xlink:actuate', 'xlink:arcrole', 'xlink:href', 'xlink:role',
       'xlink:show', 'xlink:title', 'xlink:type', 'xml:base', 'xml:lang',
       'xml:space', 'xmlns', 'xmlns:xlink', 'y', 'y1', 'y2', 'zoomAndPan']

  attr_val_is_uri = ['href', 'src', 'cite', 'action', 'longdesc', 'xlink:href']
  
  acceptable_css_properties = ['azimuth', 'background-color',
      'border-bottom-color', 'border-collapse', 'border-color',
      'border-left-color', 'border-right-color', 'border-top-color', 'clear',
      'color', 'cursor', 'direction', 'display', 'elevation', 'float', 'font',
      'font-family', 'font-size', 'font-style', 'font-variant', 'font-weight',
      'height', 'letter-spacing', 'line-height', 'overflow', 'pause',
      'pause-after', 'pause-before', 'pitch', 'pitch-range', 'richness',
      'speak', 'speak-header', 'speak-numeral', 'speak-punctuation',
      'speech-rate', 'stress', 'text-align', 'text-decoration', 'text-indent',
      'unicode-bidi', 'vertical-align', 'voice-family', 'volume',
      'white-space', 'width']

  acceptable_css_keywords = ['auto', 'aqua', 'black', 'block', 'blue',
      'bold', 'both', 'bottom', 'brown', 'center', 'collapse', 'dashed',
      'dotted', 'fuchsia', 'gray', 'green', '!important', 'italic', 'left',
      'lime', 'maroon', 'medium', 'none', 'navy', 'normal', 'nowrap', 'olive',
      'pointer', 'purple', 'red', 'right', 'solid', 'silver', 'teal', 'top',
      'transparent', 'underline', 'white', 'yellow']

  acceptable_svg_properties = [ 'fill', 'fill-opacity', 'fill-rule',
      'stroke', 'stroke-width', 'stroke-linecap', 'stroke-linejoin',
      'stroke-opacity']

  acceptable_protocols = [ 'ed2k', 'ftp', 'http', 'https', 'irc',
      'mailto', 'news', 'gopher', 'nntp', 'telnet', 'webcal',
      'xmpp', 'callto', 'feed', 'urn', 'aim', 'rsync', 'tag',
      'ssh', 'sftp', 'rtsp', 'afs' ]

      ALLOWED_ELEMENTS = acceptable_elements + mathml_elements + svg_elements  unless defined?(ALLOWED_ELEMENTS)
      ALLOWED_ATTRIBUTES = acceptable_attributes + mathml_attributes + svg_attributes unless defined?(ALLOWED_ATTRIBUTES)
      ALLOWED_CSS_PROPERTIES = acceptable_css_properties unless defined?(ALLOWED_CSS_PROPERTIES)
      ALLOWED_CSS_KEYWORDS = acceptable_css_keywords unless defined?(ALLOWED_CSS_KEYWORDS)
      ALLOWED_SVG_PROPERTIES = acceptable_svg_properties unless defined?(ALLOWED_SVG_PROPERTIES)
      ALLOWED_PROTOCOLS = acceptable_protocols unless defined?(ALLOWED_PROTOCOLS)
      ATTR_VAL_IS_URI = attr_val_is_uri unless defined?(ATTR_VAL_IS_URI)

      # Sanitize the +html+, escaping all elements not in ALLOWED_ELEMENTS, and stripping out all
      # attributes not in ALLOWED_ATTRIBUTES. Style attributes are parsed, and a restricted set,
      # specified by ALLOWED_CSS_PROPERTIES and ALLOWED_CSS_KEYWORDS, are allowed through.
      # attributes in ATTR_VAL_IS_URI are scanned, and only URI schemes specified in
      # ALLOWED_PROTOCOLS are allowed.
      # You can adjust what gets sanitized, by defining these constant arrays before this Module is loaded. 
      #
      #   sanitize_html('<script> do_nasty_stuff() </script>')
      #    => &lt;script> do_nasty_stuff() &lt;/script>
      #   sanitize_html('<a href="javascript: sucker();">Click here for $100</a>')
      #    => <a>Click here for $100</a>
      def sanitize_html(html)
        if html.index("<")
          tokenizer = HTML::Tokenizer.new(html)
          new_text = ""

          while token = tokenizer.next
            node = XHTML::Node.parse(nil, 0, 0, token, false)
            new_text << case node.tag?
              when true
                if ALLOWED_ELEMENTS.include?(node.name)
                  if node.closing != :close
                    node.attributes.delete_if { |attr,v| !ALLOWED_ATTRIBUTES.include?(attr) }
                    ATTR_VAL_IS_URI.each do |attr|
                      val_unescaped = CGI.unescapeHTML(node.attributes[attr].to_s).gsub(/[\000-\040\177\s]+|\302*[\200-\240]/,'').downcase
                      if val_unescaped =~ /^[a-z0-9][-+.a-z0-9]*:/ and !ALLOWED_PROTOCOLS.include?(val_unescaped.split(':')[0]) 
                        node.attributes.delete attr 
                      end
                    end
                    if node.attributes['style']
                      node.attributes['style'] = sanitize_css(node.attributes['style']) 
                    end
                  end
                  node.to_s
                else
                  node.to_s.gsub(/</, "&lt;")
                end
              else
                node.to_s.gsub(/</, "&lt;")
            end
          end

          html = new_text
        end
        html
      end
      
      def sanitize_css(style)
          # disallow urls
          style = style.to_s.gsub(/url\s*\(\s*[^\s)]+?\s*\)\s*/, ' ')

          # gauntlet
          if style !~ /^([:,;#%.\sa-zA-Z0-9!]|\w-\w|\'[\s\w]+\'|\"[\s\w]+\"|\([\d,\s]+\))*$/
             style = ''
             return style
          end
          if style !~ /^(\s*[-\w]+\s*:\s*[^:;]*(;|$))*$/
             style = ''
             return style
          end

          clean = []
          style.scan(/([-\w]+)\s*:\s*([^:;]*)/) do |prop,val|
            if ALLOWED_CSS_PROPERTIES.include?(prop.downcase)
              clean <<  prop + ': ' + val + ';'
            elsif ['background','border','margin','padding'].include?(prop.split('-')[0].downcase) 
              goodval = true
              val.split().each do |keyword|
                if !ALLOWED_CSS_KEYWORDS.include?(keyword) and 
                   keyword !~ /^(#[0-9a-f]+|rgb\(\d+%?,\d*%?,?\d*%?\)?|\d{0,2}\.?\d{0,2}(cm|em|ex|in|mm|pc|pt|px|%|,|\))?)$/
                  goodval = false
                end
              end
              if goodval 
                clean <<  prop + ': ' + val + ';'
              end
            elsif ALLOWED_SVG_PROPERTIES.include?(prop.downcase)
               clean <<  prop + ': ' + val + ';'
            end
          end

          style = clean.join(' ')
      end
end      
