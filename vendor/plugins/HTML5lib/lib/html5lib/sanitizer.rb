require 'cgi'

module HTML5lib

# This module provides sanitization of XHTML+MathML+SVG
# and of inline style attributes.
#
# It can be either at the Tokenizer stage:
#
#       HTMLParser.parse(html, :tokenizer => HTMLSanitizer)
#
# or, if you already have a parse tree (in this example, a REXML tree),
# at the Serializer stage:
#
#     tokens = TreeWalkers.getTreeWalker('rexml').new(tree)
#     HTMLSerializer.serialize(tokens, {:encoding=>'utf-8',
#        :sanitize => true})

   module HTMLSanitizeModule

    ACCEPTABLE_ELEMENTS = %w[a abbr acronym address area b big blockquote br
      button caption center cite code col colgroup dd del dfn dir div dl dt
      em fieldset font form h1 h2 h3 h4 h5 h6 hr i img input ins kbd label
      legend li map menu ol optgroup option p pre q s samp select small span
      strike strong sub sup table tbody td textarea tfoot th thead tr tt u
      ul var]

    MATHML_ELEMENTS = %w[maction math merror mfrac mi mmultiscripts mn mo
      mover mpadded mphantom mprescripts mroot mrow mspace msqrt mstyle msub
      msubsup msup mtable mtd mtext mtr munder munderover none]

    SVG_ELEMENTS = %w[a animate animateColor animateMotion animateTransform
      circle defs desc ellipse font-face font-face-name font-face-src g
      glyph hkern image linearGradient line marker metadata missing-glyph
      mpath path polygon polyline radialGradient rect set stop svg switch
      text title tspan use]

    ACCEPTABLE_ATTRIBUTES = %w[abbr accept accept-charset accesskey action
      align alt axis border cellpadding cellspacing char charoff charset
      checked cite class clear cols colspan color compact coords datetime
      dir disabled enctype for frame headers height href hreflang hspace id
      ismap label lang longdesc maxlength media method multiple name nohref
      noshade nowrap prompt readonly rel rev rows rowspan rules scope
      selected shape size span src start style summary tabindex target title
      type usemap valign value vspace width xml:lang]

    MATHML_ATTRIBUTES = %w[actiontype align columnalign columnalign
      columnalign columnlines columnspacing columnspan depth display
      displaystyle equalcolumns equalrows fence fontstyle fontweight frame
      height linethickness lspace mathbackground mathcolor mathvariant
      mathvariant maxsize minsize other rowalign rowalign rowalign rowlines
      rowspacing rowspan rspace scriptlevel selection separator stretchy
      width width xlink:href xlink:show xlink:type xmlns xmlns:xlink]

    SVG_ATTRIBUTES = %w[accent-height accumulate additive alphabetic
       arabic-form ascent attributeName attributeType baseProfile bbox begin
       by calcMode cap-height class color color-rendering content cx cy d dx
       dy descent display dur end fill fill-rule font-family font-size
       font-stretch font-style font-variant font-weight from fx fy g1 g2
       glyph-name gradientUnits hanging height horiz-adv-x horiz-origin-x id
       ideographic k keyPoints keySplines keyTimes lang marker-end
       marker-mid marker-start markerHeight markerUnits markerWidth
       mathematical max min name offset opacity orient origin
       overline-position overline-thickness panose-1 path pathLength points
       preserveAspectRatio r refX refY repeatCount repeatDur
       requiredExtensions requiredFeatures restart rotate rx ry slope stemh
       stemv stop-color stop-opacity strikethrough-position
       strikethrough-thickness stroke stroke-dasharray stroke-dashoffset
       stroke-linecap stroke-linejoin stroke-miterlimit stroke-opacity
       stroke-width systemLanguage target text-anchor to transform type u1
       u2 underline-position underline-thickness unicode unicode-range
       units-per-em values version viewBox visibility width widths x
       x-height x1 x2 xlink:actuate xlink:arcrole xlink:href xlink:role
       xlink:show xlink:title xlink:type xml:base xml:lang xml:space xmlns
       xmlns:xlink y y1 y2 zoomAndPan]

    ATTR_VAL_IS_URI = %w[href src cite action longdesc xlink:href xml:base]

    ACCEPTABLE_CSS_PROPERTIES = %w[azimuth background-color
      border-bottom-color border-collapse border-color border-left-color
      border-right-color border-top-color clear color cursor direction
      display elevation float font font-family font-size font-style
      font-variant font-weight height letter-spacing line-height overflow
      pause pause-after pause-before pitch pitch-range richness speak
      speak-header speak-numeral speak-punctuation speech-rate stress
      text-align text-decoration text-indent unicode-bidi vertical-align
      voice-family volume white-space width]

    ACCEPTABLE_CSS_KEYWORDS = %w[auto aqua black block blue bold both bottom
      brown center collapse dashed dotted fuchsia gray green !important
      italic left lime maroon medium none navy normal nowrap olive pointer
      purple red right solid silver teal top transparent underline white
      yellow]

    ACCEPTABLE_SVG_PROPERTIES = %w[fill fill-opacity fill-rule stroke
      stroke-width stroke-linecap stroke-linejoin stroke-opacity]

    ACCEPTABLE_PROTOCOLS = %w[ed2k ftp http https irc mailto news gopher nntp
      telnet webcal xmpp callto feed urn aim rsync tag ssh sftp rtsp afs]

    # subclasses may define their own versions of these constants
    ALLOWED_ELEMENTS = ACCEPTABLE_ELEMENTS + MATHML_ELEMENTS + SVG_ELEMENTS
    ALLOWED_ATTRIBUTES = ACCEPTABLE_ATTRIBUTES + MATHML_ATTRIBUTES + SVG_ATTRIBUTES
    ALLOWED_CSS_PROPERTIES = ACCEPTABLE_CSS_PROPERTIES
    ALLOWED_CSS_KEYWORDS = ACCEPTABLE_CSS_KEYWORDS
    ALLOWED_SVG_PROPERTIES = ACCEPTABLE_SVG_PROPERTIES
    ALLOWED_PROTOCOLS = ACCEPTABLE_PROTOCOLS

    def sanitize_token(token)
        case token[:type]
        when :StartTag, :EndTag, :EmptyTag
          if ALLOWED_ELEMENTS.include?(token[:name])
            if token.has_key? :data
              attrs = Hash[*token[:data].flatten]
              attrs.delete_if { |attr,v| !ALLOWED_ATTRIBUTES.include?(attr) }
              ATTR_VAL_IS_URI.each do |attr|
                val_unescaped = CGI.unescapeHTML(attrs[attr].to_s).gsub(/`|[\000-\040\177\s]+|\302[\200-\240]/,'').downcase
                if val_unescaped =~ /^[a-z0-9][-+.a-z0-9]*:/ and !ALLOWED_PROTOCOLS.include?(val_unescaped.split(':')[0])
                  attrs.delete attr
                end
              end
              if attrs['style']
                attrs['style'] = sanitize_css(attrs['style'])
              end
              token[:data] = attrs.map {|k,v| [k,v]}
            end
            return token
          else
            if token[:type] == :EndTag
              token[:data] = "</#{token[:name]}>"
            elsif token[:data]
              attrs = token[:data].map {|k,v| " #{k}=\"#{CGI.escapeHTML(v)}\""}.join('')
              token[:data] = "<#{token[:name]}#{attrs}>"
            else
              token[:data] = "<#{token[:name]}>"
            end
            token[:data].insert(-2,'/') if token[:type] == :EmptyTag
            token[:type] = :Characters
            token.delete(:name)
            return token
          end
        when :Comment
          token[:data] = ""
          return token
        else
          return token
        end
    end

    def sanitize_css(style)
      # disallow urls
      style = style.to_s.gsub(/url\s*\(\s*[^\s)]+?\s*\)\s*/, ' ')

      # gauntlet
      return '' unless style =~ /^([:,;#%.\sa-zA-Z0-9!]|\w-\w|\'[\s\w]+\'|\"[\s\w]+\"|\([\d,\s]+\))*$/
      return '' unless style =~ /^(\s*[-\w]+\s*:\s*[^:;]*(;|$))*$/

      clean = []
      style.scan(/([-\w]+)\s*:\s*([^:;]*)/) do |prop, val|
        next if val.empty?
        prop.downcase!
        if ALLOWED_CSS_PROPERTIES.include?(prop)
          clean << "#{prop}: #{val};"
        elsif %w[background border margin padding].include?(prop.split('-')[0])
          clean << "#{prop}: #{val};" unless val.split().any? do |keyword|
            !ALLOWED_CSS_KEYWORDS.include?(keyword) and
            keyword !~ /^(#[0-9a-f]+|rgb\(\d+%?,\d*%?,?\d*%?\)?|\d{0,2}\.?\d{0,2}(cm|em|ex|in|mm|pc|pt|px|%|,|\))?)$/
          end
        elsif ALLOWED_SVG_PROPERTIES.include?(prop)
          clean << "#{prop}: #{val};"
        end
      end

      style = clean.join(' ')
    end
  end

  class HTMLSanitizer < HTMLTokenizer
    include HTMLSanitizeModule
    def each
      super do |token|
        yield(sanitize_token(token))
      end
    end
  end

end
