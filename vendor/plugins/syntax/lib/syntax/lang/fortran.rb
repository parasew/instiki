# fortran.rb -- a free-form Fortran module for the Ruby Syntax library
#
# Copyright (C) 2009 Jason Blevins
# License: 3-clause BSD (the same as Syntax itself)

require 'syntax'

module Syntax

# A tokenizer for free-form Fortran source code.
class Fortran < Tokenizer

    # Fortran keywords
    LC_KEYWORDS =
        %w{ access assign backspace blank block call close common
            continue data dimension direct do else endif enddo end entry eof
            equivalence err exist external file fmt form format formatted
            function go to if implicit include inquire intrinsic iostat
            logical named namelist nextrec number open opened parameter pause
            print program read rec recl return rewind sequential status stop
            subroutine then type unformatted unit write save } + 
    # Fortran 90 keywords
        %w{ allocate allocatable case contains cycle deallocate
            elsewhere exit interface intent module only operator
            optional pointer private procedure public result recursive
            select sequence target use while where } +
    # Fortran 95 keywords
        %w{ elemental forall pure } +
    # Fortran 2003 keywords
        %w{ abstract asynchronous bind class delegate static reference
            round decimal sign encoding iomsg endfile nextrec pending
            pass protected associate flush decorate extends extensible
            generic non_overridable enum enumerator typealias move_alloc
            volatile }

    # List of identifiers recognized as types
    LC_TYPES =
        %w{ character double integer real precision complex }

    # Fortran intrinsic procedures
    LC_INTRINSICS = %w{
        abs achar acos acosh adjustl adjustr aimag
        aint all allocated anint any asin asinh
        associated atan atan2 atanh
        bessel_j0 bessel_j1 bessel_jn
        bessel_y0 bessel_y1 bessel_yn
        bit_size btest
        c_associated c_f_pointer c_f_procpointer
        c_funloc c_loc c_sizeof
        ceiling char cmplx command_argument_count
        conjg cos cosh count cpu_time cshift
        date_and_time dble digits dim dot_product dprod
        eoshift epsilon erf erfc erfc_scaled exp exponent
        float floor fraction
        gamma get_command get_command_argument
        get_environment_variable
        huge hypot
        iachar iand ibclr ibits ibset ichar int ior
        is_iostat_end is_iostat_eor ishft ishftc
        kind
        lbound leadz len len_trim lge lgt lle llt
        log log10 log_gamma logical
        matmul max maxexponent maxloc maxval merge
        min minexponent minloc minval mod modulo
        move_alloc mvbits
        nearest new_line nint not null
        pack precision present product
        radix random_number random_seed range real
        repeat reshape rrspacing
        scale scan selected_char_kind selected_int_kind
        selected_real_kind set_exponent shape sign
        sin sinh size sngl spacing spread sqrt sum system_clock
        tan tanh tiny trailz transfer transpose trim
        ubound unpack
        verify
    }

    # Also support all uppercase keywords, types, and procedures
    KEYWORDS = Set.new LC_KEYWORDS + LC_KEYWORDS.map { |x| x.upcase }
    TYPES = Set.new LC_TYPES + LC_TYPES.map { |x| x.upcase }
    INTRINSICS = Set.new LC_INTRINSICS + LC_INTRINSICS.map { |x| x.upcase }

    # Step through a single iteration of the tokenization process.
    def step
      case
      when check( /program\s+/ )
        start_group :keyword, scan( /program\s+/ )
        start_group :function,  scan_until( /(?=[;(\s]|#{EOL})/ )
      when check( /subroutine\s+/ )
        start_group :keyword, scan( /subroutine\s+/ )
        start_group :function,  scan_until( /(?=[;(\s]|#{EOL})/ )
      when check( /function\s+/ )
        start_group :keyword, scan( /function\s+/ )
        start_group :function,  scan_until( /(?=[;(\s]|#{EOL})/ )
      when check( /module\s+/ )
        start_group :keyword, scan( /module\s+/ )
        start_group :function,  scan_until( /(?=[;\s]|#{EOL})/ )
      when check( /\.true\.|\.false\.|\.TRUE\.|\.FALSE\./ )
        start_group :constant,
        scan(/\.true\.|\.false\.|\.TRUE\.|\.FALSE\./)
      when scan( /(\d+\.?\d*|\d*\.?\d+)([eEdDqQ][+-]?\d+)?(_\w+)?/ )
        start_group :number, matched
      when scan( /[bB]\'[01]+\'|[oO]\'[0-7]+\'|[zZ]\'[0-9a-fA-F]+\'/ )
        start_group :number, matched
      else
        case peek(1)
        when /[\n\r]/
          start_group :normal, scan( /\s+/ )
        when /\s/
          start_group :normal, scan( /\s+/ )
        when "!"
          start_group :comment, scan( /![^\n\r]*/ )
        when /[A-Za-z]/
          word = scan( /\w+/ )
          if KEYWORDS.include?(word)
            start_group :keyword, word
          elsif TYPES.include?(word)
            start_group :type, word
          elsif INTRINSICS.include?(word)
            start_group :function, word
          elsif
            start_group :ident, word
          end
        when '"'
          # allow for continuation characters within strings
          start_group :string, scan(/"([^"]*(&[ ]*[\n\r]+)?)*"/)
        when "'"
          # allow for continuation characters within strings
          start_group :string, scan(/'([^']*(&[ ]*[\n\r]+)?)*'/)
        when /[-!?*\/+=<>()\[\]\{}:;,&|%]/
          start_group :punct, scan(/./)
        else
          # pass everything else through
          append getch
        end
      end
    end

  end

  SYNTAX["fortran"] = Fortran

end
