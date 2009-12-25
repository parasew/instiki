require 'syntax'

module Syntax

  class CSS21 < Tokenizer

    CSS21_PROPERTIES = Set.new %w{font-family font-style font-variant font-weight
      font-size font background-color background-image
      background-repeat background-attachment background-position
      color background word-spacing letter-spacing
      border-top-width border-right-width border-left-width
      border-bottom-width border-width list-style-type
      list-style-image list-style-position text-decoration
      vertical-align text-transform text-align text-indent
      line-height margin-top margin-right margin-bottom
      margin-left margin padding-top padding-right padding-bottom
      padding-left padding border-top border-right border-bottom
      border-left border width height float clear display
      list-style white-space border-style border-color
      azimuth border-bottom-color border-bottom-style
      border-collapse border-left-color border-left-style
      border-right-color border-right-style border-top-color
      border-top-style caption-side cell-spacing clip column-span
      content cue cue-after cue-before cursor direction
      elevation font-size-adjust marks max-height max-width
      min-height min-width orphans overflow page-break-after
      page-break-before pause pause-after pause-before pitch
      pitch-range play-during position richness right row-span
      size speak speak-date speak-header speak-punctuation
      speak-time speech-rate stress table-layout text-shadow top
      visibility voice-family volume
      widows z-index quotes
      marker-offset outline outline-color outline-style outline-width
      border-spacing border-collapse
      page-break-before page-break-after page-break-inside
      orphans widows} unless const_defined?(:CSS21_PROPERTIES)

    CSS21_KEYWORDS = Set.new %w{maroon red orange yellow olive purple
      fuchsia white lime green navy blue aqua teal black silver gray
      scroll fixed transparent none top center bottom
      left right repeat repeat-x repeat-y no-repeat
      thin medium thick dotted dashed solid double groove ridge
      inset outset both block inline list-item
      xx-small x-small small medium large x-large xx-large
      smaller italic oblique small-caps bold bolder lighter auto
      disc circle square decimal lower-roman upper-roman lower-alpha
      upper-alpha inside outside justify underline overline line-through
      blink capitalize uppercase lowercase baseline sub super
      top text-top middle bottom text-bottom pre nowrap
      compact run-in inherit caption icon menu message-box small-caption
      status-bar marker
      table inline-table table-column-group table-column
      table-row-group table-row table-cell table-caption
      table-header-group table-footer-group
      screen print projection braille embosed aural tv
      tty handheld cross hidden open-quote close-quote
      absolute relative normal collapse
      serif sans-serif monospace cursive
      fantasy, always} unless const_defined?(:CSS21_KEYWORDS)

    HTML_TAGS = Set.new %w{a abbr address area article aside
      audio b base bdo blockquote body br button canvas caption
      cite code col colgroup command datalist dd del details dfn
      div dl dt em embed fieldset figure footer form h1 h2 h3
      h4 h5 h6 head header hgroup hr html i iframe img input ins
      kbd keygen label legend li link map mark menu meta meter
      nav noscript object ol optgroup option output p param pre
      progress q rp rt ruby samp script section select small
      source span strong style sub sup table tbody td textarea
      tfoot th thead time title tr ul var video
      acronym applet big center frame frameset isindex marquee
      noframes s tt u} unless const_defined?(:HTML_TAGS)

    MATHML_TAGS = Set.new %w{annotation annotation-xml maction
      malign maligngroup malignmark malignscope math menclose
      merror mfenced mfrac mglyph mi mlabeledtr mlongdiv mmultiscripts
      mn mo mover mpadded mphantom mprescripts mroot mrow ms mscarries
      mscarry msgroup msline mspace msqrt msrow mstack mstyle msub
      msubsup msup mtable mtd mtext mtr munder munderover none
      semantics} unless const_defined?(:MATHML_TAGS)

    SVG_TAGS = Set.new %w{a altGlyph altGlyphDef altGlyphItem animate
      animateColor animateMotion animateTransform circle clipPath
      color-profile cursor definition-src defs desc ellipse feBlend
      feColorMatrix feComponentTransfer feComposite feConvolveMatrix
      feDiffuseLighting feDisplacementMap feDistantLight feFlood feFuncA
      feFuncB feFuncG feFuncR feGaussianBlur feImage feMerge feMergeNode
      feMorphology feOffset fePointLight feSpecularLighting feSpotLight
      feTile feTurbulence filter font font-face font-face-format
      font-face-name font-face-src font-face-uri foreignObject g glyph
      glyphRef hkern image line linearGradient marker mask metadata
      missing-glyph mpath path pattern polygon polyline radialGradient
      rect script set stop style svg switch symbol text textPath title
      tref tspan use view vkern} unless const_defined?(:SVG_TAGS)
      
    MY_TAGS = HTML_TAGS + MATHML_TAGS + SVG_TAGS unless const_defined?(:MY_TAGS)

    def setup
      @selector = true
      @macros = {}
      @tokens = {}

      # http://www.w3.org/TR/CSS21/syndata.html
      macro(:h, /([0-9a-fA-F])/ ) # uppercase A-Z added?
      macro(:nonascii, /([^\000-\177])/ )
      macro(:nl, /(\n|\r\n|\r|\f)/ )
      macro(:unicode, /(\\#{m(:h)}{1,6}(\r\n|[ \t\r\n\f])?)/ )
      macro(:escape, /(#{m(:unicode)}|\\[^\r\n\f0-9a-f])/ )
      macro(:nmstart, /([_a-z]|#{m(:nonascii)}|#{m(:escape)})/ )
      macro(:nmchar, /([_a-z0-9-]|#{m(:nonascii)}|#{m(:escape)})/ )
      macro(:string1, /(\"([^\n\r\f\\\"]|\\#{m(:nl)}|#{m(:escape)})*\")/ )
      macro(:string2, /(\'([^\n\r\f\\']|\\#{m(:nl)}|#{m(:escape)})*\')/ )
      macro(:invalid1, /(\"([^\n\r\f\\\"]|\\#{m(:nl)}|#{m(:escape)})*)/ )
      macro(:invalid2, /(\'([^\n\r\f\\']|\\#{m(:nl)}|#{m(:escape)})*)/ )
      macro(:comment, /(\/\*[^*]*\*+([^\/*][^*]*\*+)*\/)/ )
      macro(:ident, /(-?#{m(:nmstart)}#{m(:nmchar)}*)/ )
      macro(:name, /(#{m(:nmchar)}+)/ )
      macro(:num, /([0-9]+|[0-9]*\.[0-9]+)/ )
      macro(:string, /(#{m(:string1)}|#{m(:string2)})/ )
      macro(:invalid, /(#{m(:invalid1)}|#{m(:invalid2)})/ )
      macro(:s, /([ \t\r\n\f]+)/ )
      macro(:w, /(#{m(:s)}?)/ )
      macro(:A, /(a|\\0{0,4}(41|61)(\r\n|[ \t\r\n\f])?)/ )
      macro(:C, /(c|\\0{0,4}(43|63)(\r\n|[ \t\r\n\f])?)/ )
      macro(:D, /(d|\\0{0,4}(44|64)(\r\n|[ \t\r\n\f])?)/ )
      macro(:E, /(e|\\0{0,4}(45|65)(\r\n|[ \t\r\n\f])?)/ )
      macro(:G, /(g|\\0{0,4}(47|67)(\r\n|[ \t\r\n\f])?|\\g)/ )
      macro(:H, /(h|\\0{0,4}(48|68)(\r\n|[ \t\r\n\f])?|\\h)/ )
      macro(:I, /(i|\\0{0,4}(49|69)(\r\n|[ \t\r\n\f])?|\\i)/ )
      macro(:K, /(k|\\0{0,4}(4b|6b)(\r\n|[ \t\r\n\f])?|\\k)/ )
      macro(:M, /(m|\\0{0,4}(4d|6d)(\r\n|[ \t\r\n\f])?|\\m)/ )
      macro(:N, /(n|\\0{0,4}(4e|6e)(\r\n|[ \t\r\n\f])?|\\n)/ )
      macro(:O, /(o|\\0{0,4}(51|71)(\r\n|[ \t\r\n\f])?|\\o)/ )
      macro(:P, /(p|\\0{0,4}(50|70)(\r\n|[ \t\r\n\f])?|\\p)/ )
      macro(:R, /(r|\\0{0,4}(52|72)(\r\n|[ \t\r\n\f])?|\\r)/ )
      macro(:S, /(s|\\0{0,4}(53|73)(\r\n|[ \t\r\n\f])?|\\s)/ )
      macro(:T, /(t|\\0{0,4}(54|74)(\r\n|[ \t\r\n\f])?|\\t)/ )
      macro(:X, /(x|\\0{0,4}(58|78)(\r\n|[ \t\r\n\f])?|\\x)/ )
      macro(:Z, /(z|\\0{0,4}(5a|7a)(\r\n|[ \t\r\n\f])?|\\z)/ )

      token(:COMMENT, /#{m(:comment)}/)

      token(:HASH, /\#/)
      token(:IDENT, /#{m(:ident)}/)
      token(:LBRACE, /#{m(:w)}\{/)
      token(:RBRACE, /#{m(:w)}\}/)

      token(:S, /#{m(:s)}/)

      token(:FUNCTION, /#{m(:ident)}(?=\()/)

      token(:PLUS, /#{m(:w)}\+/)
      token(:GREATER, /#{m(:w)}>/)
      token(:COMMA, /#{m(:w)},/)

      token(:CDO, /<!--/)
      token(:CDC, /-->/)
      token(:INCLUDES, /~=/)
      token(:DASHMATCH, /\|=/)
      token(:STRING, /#{m(:string)}/)
      token(:INVALID, /#{m(:invalid)}/)
      token(:IMPORT_SYM, /@#{m(:I)}#{m(:M)}#{m(:P)}#{m(:O)}#{m(:R)}#{m(:T)}/)
      token(:PAGE_SYM, /@#{m(:P)}#{m(:A)}#{m(:G)}#{m(:E)}/)
      token(:MEDIA_SYM, /@#{m(:M)}#{m(:E)}#{m(:D)}#{m(:I)}#{m(:A)}/)
      token(:CHARSET_SYM, /@#{m(:C)}#{m(:H)}#{m(:A)}#{m(:R)}#{m(:S)}#{m(:E)}#{m(:T)}/)
      token(:IMPORTANT_SYM, /!(#{m(:w)}|#{m(:comment)})*#{m(:I)}#{m(:M)}#{m(:P)}#{m(:O)}#{m(:R)}#{m(:T)}#{m(:A)}#{m(:N)}#{m(:T)}/)
      token(:EMS, /#{m(:num)}#{m(:E)}#{m(:M)}/)
      token(:EXS, /#{m(:num)}#{m(:E)}#{m(:X)}/)

      token :LENGTH do |patterns|
        patterns << /#{m(:num)}#{m(:P)}#{m(:X)}/
        patterns << /#{m(:num)}#{m(:C)}#{m(:M)}/
        patterns << /#{m(:num)}#{m(:M)}#{m(:M)}/
        patterns << /#{m(:num)}#{m(:I)}#{m(:N)}/
        patterns << /#{m(:num)}#{m(:P)}#{m(:T)}/
        patterns << /#{m(:num)}#{m(:P)}#{m(:C)}/
      end

      token :ANGLE do |patterns|
        patterns << /#{m(:num)}#{m(:D)}#{m(:E)}#{m(:G)}/
        patterns << /#{m(:num)}#{m(:R)}#{m(:A)}#{m(:D)}/
        patterns << /#{m(:num)}#{m(:G)}#{m(:R)}#{m(:A)}#{m(:D)}/
      end

      token :TIME do |patterns|
        patterns << /#{m(:num)}#{m(:M)}#{m(:S)}/
        patterns << /#{m(:num)}#{m(:S)}/
      end

      token :FREQ do |patterns|
        patterns << /#{m(:num)}#{m(:H)}#{m(:Z)}/
        patterns << /#{m(:num)}#{m(:K)}#{m(:H)}#{m(:Z)}/
      end

      token :URI do |patterns|
        patterns << /url\(#{m(:w)}#{m(:string)}#{m(:w)}\)/
        patterns << /url\(#{m(:w)}([!$%&*-~]|#{m(:nonascii)}|#{m(:escape)})*#{m(:w)}\)/
      end

      token(:DIMENSION, /#{m(:num)}#{m(:ident)}/)
      token(:PERCENTAGE, /#{m(:num)}%/)
      token(:HEXNUM, /##{m(:h)}{2,6}/)
      token(:NUMBER, /#{m(:num)}/)

    end

    def step

      case

      # scanning selectors only
      when @selector && scan(@tokens[:LBRACE])
        @selector = false
        start_group :normal, matched
      when @selector && scan(@tokens[:IMPORT_SYM])
        start_group :import, matched
      when @selector && scan(@tokens[:PAGE_SYM])
        start_group :page, matched
      when @selector && scan(@tokens[:MEDIA_SYM])
        start_group :media, matched
      when @selector && scan(@tokens[:CHARSET_SYM])
        start_group :charset, matched
      when @selector && scan(@tokens[:HASH])
        start_group :normal, matched
      when @selector && scan(@tokens[:URI])
        start_group :uri, matched

      when @selector && scan(@tokens[:IDENT])
        if MY_TAGS.include?( matched )
          start_group :tag, matched
        else
          start_group :ident, matched
        end

      # scanning declarations only
      when !@selector && scan(@tokens[:RBRACE])
        @selector = true
        start_group :normal, matched
      when !@selector && scan(@tokens[:FUNCTION])
        start_group :function, matched
      when !@selector && scan(@tokens[:EMS])
        start_group :ems, matched
      when !@selector && scan(@tokens[:EXS])
        start_group :exs, matched
      when !@selector && scan(@tokens[:LENGTH])
        start_group :length, matched
      when !@selector && scan(@tokens[:ANGLE])
        start_group :angle, matched
      when !@selector && scan(@tokens[:TIME])
        start_group :time, matched
      when !@selector && scan(@tokens[:FREQ])
        start_group :freq, matched
      when !@selector && scan(@tokens[:PERCENTAGE])
        start_group :percentage, matched
      when !@selector && scan(@tokens[:DIMENSION])
        start_group :dimension, matched
      when !@selector && scan(@tokens[:NUMBER])
        start_group :number, matched
      when !@selector && scan(@tokens[:HEXNUM])
        start_group :number, matched
      when !@selector && scan(@tokens[:IMPORTANT_SYM])
        start_group :important, matched

      when !@selector && scan(@tokens[:IDENT])
        if CSS21_PROPERTIES.include?( matched ) # are they disjoint?
          start_group :property, matched
        elsif CSS21_KEYWORDS.include?( matched )
          start_group :keyword, matched
        else
          start_group :ident, matched
        end

      # scanning both
      when scan(@tokens[:S])
        start_group :normal, matched
      when scan(@tokens[:COMMENT])
        start_group :comment, matched
      when scan(@tokens[:STRING])
        start_group :string, matched
      when scan(@tokens[:CDO])
        start_group :cdo, matched
      when scan(@tokens[:CDC])
        start_group :cdc, matched
      when scan(@tokens[:INVALID])
        start_group :invalid, matched
      else
        start_group :normal, scan(/./x)
      end

    end

    private

    def macro(name, regex=nil)
      regex ? @macros[name] = regex : @macros[name].source
    end

    def token(name, pattern=nil, &block)
      raise ArgumentError, "name required" unless name

      patterns = []
      patterns << pattern if pattern
      yield(patterns) if block_given?
      if patterns.empty?
        raise ArgumentError, "at least one pattern required"
      end
      patterns.collect! do |pattern|
        source = pattern.source
        source = "\\A#{source}"
        Regexp.new(source, Regexp::IGNORECASE + Regexp::MULTILINE)
      end

      @tokens[name] = Regexp.union(*patterns)
    end

    alias :m :macro

  end

  SYNTAX["css21"] = CSS21

end


