module HTML5lib

  class EOF < Exception; end

  CONTENT_MODEL_FLAGS = [
      :PCDATA,
      :RCDATA,
      :CDATA,
      :PLAINTEXT
  ]

  SCOPING_ELEMENTS = %w[
      button
      caption
      html
      marquee
      object
      table
      td
      th
  ]

  FORMATTING_ELEMENTS = %w[
      a
      b
      big
      em
      font
      i
      nobr
      s
      small
      strike
      strong
      tt
      u
  ]

  SPECIAL_ELEMENTS = %w[
      address
      area
      base
      basefont
      bgsound
      blockquote
      body
      br
      center
      col
      colgroup
      dd
      dir
      div
      dl
      dt
      embed
      fieldset
      form
      frame
      frameset
      h1
      h2
      h3
      h4
      h5
      h6
      head
      hr
      iframe
      image
      img
      input
      isindex
      li
      link
      listing
      menu
      meta
      noembed
      noframes
      noscript
      ol
      optgroup
      option
      p
      param
      plaintext
      pre
      script
      select
      spacer
      style
      tbody
      textarea
      tfoot
      thead
      title
      tr
      ul
      wbr
  ]

  SPACE_CHARACTERS = %W[
      \t
      \n
      \x0B
      \x0C
      \x20
      \r
  ]

  TABLE_INSERT_MODE_ELEMENTS = %w[
      table
      tbody
      tfoot
      thead
      tr
  ]

  ASCII_LOWERCASE = ('a'..'z').to_a.join('')
  ASCII_UPPERCASE = ('A'..'Z').to_a.join('')
  ASCII_LETTERS = ASCII_LOWERCASE + ASCII_UPPERCASE
  DIGITS = '0'..'9'
  HEX_DIGITS = DIGITS.to_a + ('a'..'f').to_a + ('A'..'F').to_a

  # Heading elements need to be ordered 
  HEADING_ELEMENTS = %w[
      h1
      h2
      h3
      h4
      h5
      h6
  ]

  # XXX What about event-source and command?
  VOID_ELEMENTS = %w[
      base
      link
      meta
      hr
      br
      img
      embed
      param
      area
      col
      input
  ]

  CDATA_ELEMENTS = %w[title textarea]

  RCDATA_ELEMENTS = %w[
    style
    script
    xmp
    iframe
    noembed
    noframes
    noscript
  ]

  BOOLEAN_ATTRIBUTES = {
    :global => %w[irrelevant],
    'style' => %w[scoped],
    'img' => %w[ismap],
    'audio' => %w[autoplay controls],
    'video' => %w[autoplay controls],
    'script' => %w[defer async],
    'details' => %w[open],
    'datagrid' => %w[multiple disabled],
    'command' => %w[hidden disabled checked default],
    'menu' => %w[autosubmit],
    'fieldset' => %w[disabled readonly],
    'option' => %w[disabled readonly selected],
    'optgroup' => %w[disabled readonly],
    'button' => %w[disabled autofocus],
    'input' => %w[disabled readonly required autofocus checked ismap],
    'select' => %w[disabled readonly autofocus multiple],
    'output' => %w[disabled readonly]
  }

  # entitiesWindows1252 has to be _ordered_ and needs to have an index.
  ENTITIES_WINDOWS1252 = [
      8364,  # 0x80  0x20AC  EURO SIGN
      65533, # 0x81          UNDEFINED
      8218,  # 0x82  0x201A  SINGLE LOW-9 QUOTATION MARK
      402,   # 0x83  0x0192  LATIN SMALL LETTER F WITH HOOK
      8222,  # 0x84  0x201E  DOUBLE LOW-9 QUOTATION MARK
      8230,  # 0x85  0x2026  HORIZONTAL ELLIPSIS
      8224,  # 0x86  0x2020  DAGGER
      8225,  # 0x87  0x2021  DOUBLE DAGGER
      710,   # 0x88  0x02C6  MODIFIER LETTER CIRCUMFLEX ACCENT
      8240,  # 0x89  0x2030  PER MILLE SIGN
      352,   # 0x8A  0x0160  LATIN CAPITAL LETTER S WITH CARON
      8249,  # 0x8B  0x2039  SINGLE LEFT-POINTING ANGLE QUOTATION MARK
      338,   # 0x8C  0x0152  LATIN CAPITAL LIGATURE OE
      65533, # 0x8D          UNDEFINED
      381,   # 0x8E  0x017D  LATIN CAPITAL LETTER Z WITH CARON
      65533, # 0x8F          UNDEFINED
      65533, # 0x90          UNDEFINED
      8216,  # 0x91  0x2018  LEFT SINGLE QUOTATION MARK
      8217,  # 0x92  0x2019  RIGHT SINGLE QUOTATION MARK
      8220,  # 0x93  0x201C  LEFT DOUBLE QUOTATION MARK
      8221,  # 0x94  0x201D  RIGHT DOUBLE QUOTATION MARK
      8226,  # 0x95  0x2022  BULLET
      8211,  # 0x96  0x2013  EN DASH
      8212,  # 0x97  0x2014  EM DASH
      732,   # 0x98  0x02DC  SMALL TILDE
      8482,  # 0x99  0x2122  TRADE MARK SIGN
      353,   # 0x9A  0x0161  LATIN SMALL LETTER S WITH CARON
      8250,  # 0x9B  0x203A  SINGLE RIGHT-POINTING ANGLE QUOTATION MARK
      339,   # 0x9C  0x0153  LATIN SMALL LIGATURE OE
      65533, # 0x9D          UNDEFINED
      382,   # 0x9E  0x017E  LATIN SMALL LETTER Z WITH CARON
      376    # 0x9F  0x0178  LATIN CAPITAL LETTER Y WITH DIAERESIS
  ]

  private

    def self.U n
      [n].pack('U')
    end

  public

  ENTITIES = {
      "AElig" => U(0xC6),
      "Aacute" => U(0xC1),
      "Acirc" => U(0xC2),
      "Agrave" => U(0xC0),
      "Alpha" => U(0x0391),
      "Aring" => U(0xC5),
      "Atilde" => U(0xC3),
      "Auml" => U(0xC4),
      "Beta" => U(0x0392),
      "Ccedil" => U(0xC7),
      "Chi" => U(0x03A7),
      "Dagger" => U(0x2021),
      "Delta" => U(0x0394),
      "ETH" => U(0xD0),
      "Eacute" => U(0xC9),
      "Ecirc" => U(0xCA),
      "Egrave" => U(0xC8),
      "Epsilon" => U(0x0395),
      "Eta" => U(0x0397),
      "Euml" => U(0xCB),
      "Gamma" => U(0x0393),
      "Iacute" => U(0xCD),
      "Icirc" => U(0xCE),
      "Igrave" => U(0xCC),
      "Iota" => U(0x0399),
      "Iuml" => U(0xCF),
      "Kappa" => U(0x039A),
      "Lambda" => U(0x039B),
      "Mu" => U(0x039C),
      "Ntilde" => U(0xD1),
      "Nu" => U(0x039D),
      "OElig" => U(0x0152),
      "Oacute" => U(0xD3),
      "Ocirc" => U(0xD4),
      "Ograve" => U(0xD2),
      "Omega" => U(0x03A9),
      "Omicron" => U(0x039F),
      "Oslash" => U(0xD8),
      "Otilde" => U(0xD5),
      "Ouml" => U(0xD6),
      "Phi" => U(0x03A6),
      "Pi" => U(0x03A0),
      "Prime" => U(0x2033),
      "Psi" => U(0x03A8),
      "Rho" => U(0x03A1),
      "Scaron" => U(0x0160),
      "Sigma" => U(0x03A3),
      "THORN" => U(0xDE),
      "Tau" => U(0x03A4),
      "Theta" => U(0x0398),
      "Uacute" => U(0xDA),
      "Ucirc" => U(0xDB),
      "Ugrave" => U(0xD9),
      "Upsilon" => U(0x03A5),
      "Uuml" => U(0xDC),
      "Xi" => U(0x039E),
      "Yacute" => U(0xDD),
      "Yuml" => U(0x0178),
      "Zeta" => U(0x0396),
      "aacute" => U(0xE1),
      "acirc" => U(0xE2),
      "acute" => U(0xB4),
      "aelig" => U(0xE6),
      "agrave" => U(0xE0),
      "alefsym" => U(0x2135),
      "alpha" => U(0x03B1),
      "amp" => U(0x26),
      "AMP" => U(0x26),
      "and" => U(0x2227),
      "ang" => U(0x2220),
      "apos" => U(0x27),
      "aring" => U(0xE5),
      "asymp" => U(0x2248),
      "atilde" => U(0xE3),
      "auml" => U(0xE4),
      "bdquo" => U(0x201E),
      "beta" => U(0x03B2),
      "brvbar" => U(0xA6),
      "bull" => U(0x2022),
      "cap" => U(0x2229),
      "ccedil" => U(0xE7),
      "cedil" => U(0xB8),
      "cent" => U(0xA2),
      "chi" => U(0x03C7),
      "circ" => U(0x02C6),
      "clubs" => U(0x2663),
      "cong" => U(0x2245),
      "copy" => U(0xA9),
      "COPY" => U(0xA9),
      "crarr" => U(0x21B5),
      "cup" => U(0x222A),
      "curren" => U(0xA4),
      "dArr" => U(0x21D3),
      "dagger" => U(0x2020),
      "darr" => U(0x2193),
      "deg" => U(0xB0),
      "delta" => U(0x03B4),
      "diams" => U(0x2666),
      "divide" => U(0xF7),
      "eacute" => U(0xE9),
      "ecirc" => U(0xEA),
      "egrave" => U(0xE8),
      "empty" => U(0x2205),
      "emsp" => U(0x2003),
      "ensp" => U(0x2002),
      "epsilon" => U(0x03B5),
      "equiv" => U(0x2261),
      "eta" => U(0x03B7),
      "eth" => U(0xF0),
      "euml" => U(0xEB),
      "euro" => U(0x20AC),
      "exist" => U(0x2203),
      "fnof" => U(0x0192),
      "forall" => U(0x2200),
      "frac12" => U(0xBD),
      "frac14" => U(0xBC),
      "frac34" => U(0xBE),
      "frasl" => U(0x2044),
      "gamma" => U(0x03B3),
      "ge" => U(0x2265),
      "gt" => U(0x3E),
      "GT" => U(0x3E),
      "hArr" => U(0x21D4),
      "harr" => U(0x2194),
      "hearts" => U(0x2665),
      "hellip" => U(0x2026),
      "iacute" => U(0xED),
      "icirc" => U(0xEE),
      "iexcl" => U(0xA1),
      "igrave" => U(0xEC),
      "image" => U(0x2111),
      "infin" => U(0x221E),
      "int" => U(0x222B),
      "iota" => U(0x03B9),
      "iquest" => U(0xBF),
      "isin" => U(0x2208),
      "iuml" => U(0xEF),
      "kappa" => U(0x03BA),
      "lArr" => U(0x21D0),
      "lambda" => U(0x03BB),
      "lang" => U(0x2329),
      "laquo" => U(0xAB),
      "larr" => U(0x2190),
      "lceil" => U(0x2308),
      "ldquo" => U(0x201C),
      "le" => U(0x2264),
      "lfloor" => U(0x230A),
      "lowast" => U(0x2217),
      "loz" => U(0x25CA),
      "lrm" => U(0x200E),
      "lsaquo" => U(0x2039),
      "lsquo" => U(0x2018),
      "lt" => U(0x3C),
      "LT" => U(0x3C),
      "macr" => U(0xAF),
      "mdash" => U(0x2014),
      "micro" => U(0xB5),
      "middot" => U(0xB7),
      "minus" => U(0x2212),
      "mu" => U(0x03BC),
      "nabla" => U(0x2207),
      "nbsp" => U(0xA0),
      "ndash" => U(0x2013),
      "ne" => U(0x2260),
      "ni" => U(0x220B),
      "not" => U(0xAC),
      "notin" => U(0x2209),
      "nsub" => U(0x2284),
      "ntilde" => U(0xF1),
      "nu" => U(0x03BD),
      "oacute" => U(0xF3),
      "ocirc" => U(0xF4),
      "oelig" => U(0x0153),
      "ograve" => U(0xF2),
      "oline" => U(0x203E),
      "omega" => U(0x03C9),
      "omicron" => U(0x03BF),
      "oplus" => U(0x2295),
      "or" => U(0x2228),
      "ordf" => U(0xAA),
      "ordm" => U(0xBA),
      "oslash" => U(0xF8),
      "otilde" => U(0xF5),
      "otimes" => U(0x2297),
      "ouml" => U(0xF6),
      "para" => U(0xB6),
      "part" => U(0x2202),
      "permil" => U(0x2030),
      "perp" => U(0x22A5),
      "phi" => U(0x03C6),
      "pi" => U(0x03C0),
      "piv" => U(0x03D6),
      "plusmn" => U(0xB1),
      "pound" => U(0xA3),
      "prime" => U(0x2032),
      "prod" => U(0x220F),
      "prop" => U(0x221D),
      "psi" => U(0x03C8),
      "quot" => U(0x22),
      "QUOT" => U(0x22),
      "rArr" => U(0x21D2),
      "radic" => U(0x221A),
      "rang" => U(0x232A),
      "raquo" => U(0xBB),
      "rarr" => U(0x2192),
      "rceil" => U(0x2309),
      "rdquo" => U(0x201D),
      "real" => U(0x211C),
      "reg" => U(0xAE),
      "REG" => U(0xAE),
      "rfloor" => U(0x230B),
      "rho" => U(0x03C1),
      "rlm" => U(0x200F),
      "rsaquo" => U(0x203A),
      "rsquo" => U(0x2019),
      "sbquo" => U(0x201A),
      "scaron" => U(0x0161),
      "sdot" => U(0x22C5),
      "sect" => U(0xA7),
      "shy" => U(0xAD),
      "sigma" => U(0x03C3),
      "sigmaf" => U(0x03C2),
      "sim" => U(0x223C),
      "spades" => U(0x2660),
      "sub" => U(0x2282),
      "sube" => U(0x2286),
      "sum" => U(0x2211),
      "sup" => U(0x2283),
      "sup1" => U(0xB9),
      "sup2" => U(0xB2),
      "sup3" => U(0xB3),
      "supe" => U(0x2287),
      "szlig" => U(0xDF),
      "tau" => U(0x03C4),
      "there4" => U(0x2234),
      "theta" => U(0x03B8),
      "thetasym" => U(0x03D1),
      "thinsp" => U(0x2009),
      "thorn" => U(0xFE),
      "tilde" => U(0x02DC),
      "times" => U(0xD7),
      "trade" => U(0x2122),
      "uArr" => U(0x21D1),
      "uacute" => U(0xFA),
      "uarr" => U(0x2191),
      "ucirc" => U(0xFB),
      "ugrave" => U(0xF9),
      "uml" => U(0xA8),
      "upsih" => U(0x03D2),
      "upsilon" => U(0x03C5),
      "uuml" => U(0xFC),
      "weierp" => U(0x2118),
      "xi" => U(0x03BE),
      "yacute" => U(0xFD),
      "yen" => U(0xA5),
      "yuml" => U(0xFF),
      "zeta" => U(0x03B6),
      "zwj" => U(0x200D),
      "zwnj" => U(0x200C)
  }

  ENCODINGS = %w[
      ansi_x3.4-1968
      iso-ir-6
      ansi_x3.4-1986
      iso_646.irv:1991
      ascii
      iso646-us
      us-ascii
      us
      ibm367
      cp367
      csascii
      ks_c_5601-1987
      korean
      iso-2022-kr
      csiso2022kr
      euc-kr
      iso-2022-jp
      csiso2022jp
      iso-2022-jp-2
      iso-ir-58
      chinese
      csiso58gb231280
      iso_8859-1:1987
      iso-ir-100
      iso_8859-1
      iso-8859-1
      latin1
      l1
      ibm819
      cp819
      csisolatin1
      iso_8859-2:1987
      iso-ir-101
      iso_8859-2
      iso-8859-2
      latin2
      l2
      csisolatin2
      iso_8859-3:1988
      iso-ir-109
      iso_8859-3
      iso-8859-3
      latin3
      l3
      csisolatin3
      iso_8859-4:1988
      iso-ir-110
      iso_8859-4
      iso-8859-4
      latin4
      l4
      csisolatin4
      iso_8859-6:1987
      iso-ir-127
      iso_8859-6
      iso-8859-6
      ecma-114
      asmo-708
      arabic
      csisolatinarabic
      iso_8859-7:1987
      iso-ir-126
      iso_8859-7
      iso-8859-7
      elot_928
      ecma-118
      greek
      greek8
      csisolatingreek
      iso_8859-8:1988
      iso-ir-138
      iso_8859-8
      iso-8859-8
      hebrew
      csisolatinhebrew
      iso_8859-5:1988
      iso-ir-144
      iso_8859-5
      iso-8859-5
      cyrillic
      csisolatincyrillic
      iso_8859-9:1989
      iso-ir-148
      iso_8859-9
      iso-8859-9
      latin5
      l5
      csisolatin5
      iso-8859-10
      iso-ir-157
      l6
      iso_8859-10:1992
      csisolatin6
      latin6
      hp-roman8
      roman8
      r8
      ibm037
      cp037
      csibm037
      ibm424
      cp424
      csibm424
      ibm437
      cp437
      437
      cspc8codepage437
      ibm500
      cp500
      csibm500
      ibm775
      cp775
      cspc775baltic
      ibm850
      cp850
      850
      cspc850multilingual
      ibm852
      cp852
      852
      cspcp852
      ibm855
      cp855
      855
      csibm855
      ibm857
      cp857
      857
      csibm857
      ibm860
      cp860
      860
      csibm860
      ibm861
      cp861
      861
      cp-is
      csibm861
      ibm862
      cp862
      862
      cspc862latinhebrew
      ibm863
      cp863
      863
      csibm863
      ibm864
      cp864
      csibm864
      ibm865
      cp865
      865
      csibm865
      ibm866
      cp866
      866
      csibm866
      ibm869
      cp869
      869
      cp-gr
      csibm869
      ibm1026
      cp1026
      csibm1026
      koi8-r
      cskoi8r
      koi8-u
      big5-hkscs
      ptcp154
      csptcp154
      pt154
      cp154
      utf-7
      utf-16be
      utf-16le
      utf-16
      utf-8
      iso-8859-13
      iso-8859-14
      iso-ir-199
      iso_8859-14:1998
      iso_8859-14
      latin8
      iso-celtic
      l8
      iso-8859-15
      iso_8859-15
      iso-8859-16
      iso-ir-226
      iso_8859-16:2001
      iso_8859-16
      latin10
      l10
      gbk
      cp936
      ms936
      gb18030
      shift_jis
      ms_kanji
      csshiftjis
      euc-jp
      gb2312
      big5
      csbig5
      windows-1250
      windows-1251
      windows-1252
      windows-1253
      windows-1254
      windows-1255
      windows-1256
      windows-1257
      windows-1258
      tis-620
      hz-gb-2312
  ]

end
