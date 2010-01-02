require 'syntax'

module Syntax

  class AnsiC < Tokenizer
    
    def self.add_type(name)
      ANSIC_PREDEFINED_TYPES << name
    end
    
    ANSIC_KEYWORDS =
      Set.new %w{asm break case continue default do else for goto if return
         switch while struct union enum typedef static register
         auto extern sizeof volatile const inline restrict} unless const_defined?(:ANSIC_KEYWORDS)

    ANSIC_PREDEFINED_TYPES =
      Set.new %w{int long short char void signed unsigned 
         float double bool complex} unless const_defined?(:ANSIC_PREDEFINED_TYPES)

    ANSIC_PREDEFINED_CONSTANTS =
      %w{EOF NULL true false} unless const_defined?(:ANSIC_PREDEFINED_CONSTANTS)

    ANSIC_ESCAPE = / [rbfnrtv\n\\'"] | x[a-fA-F0-9]{1,2} | [0-7]{1,3} /x unless const_defined?(:ANSIC_ESCAPE)

    def step
      case
      when scan(/\s+/)
        start_group :normal, matched
      when match = scan(/#\s*(\w*)/)
        match << scan_until(/\n/)
        start_group :preprocessor, match
      when scan(/ L?' (?: [^\'\n\\] | \\ #{ANSIC_ESCAPE} )? '? /ox)
        start_group :char, matched
      when scan(/0[xX][0-9A-Fa-f]+/)
        start_group :hex, matched
      when scan(/(?:0[0-7]+)(?![89.eEfF])/)
        start_group :oct, matched
      when scan(/(?:\d+)(?![.eEfF])/)
        start_group :integer, matched
      when scan(/\d[fF]?|\d*\.\d+(?:[eE][+-]?\d+)?[fF]?|\d+[eE][+-]?\d+[fF]?/)
        start_group :float, matched
      when scan(/"(?:[^"\\]|\\.)*"/)
        start_group :string, matched
      when scan( %r{ ('(?: . | [\t\b\n] )') }x )
        start_group :char, matched
      when scan(/[a-z_][a-z_\d]+/)
        if ANSIC_KEYWORDS.include?( matched )
          start_group :keyword, matched
        elsif ANSIC_PREDEFINED_TYPES.include?( matched )
          start_group :predefined_types, matched
        else
          start_group :ident, matched
        end
      when scan(%r! // [^\n\\]* (?: \\. [^\n\\]* )* | /\* (?: .*? \*/ | .* ) !mx)
        start_group :comment, matched
      else
        start_group :other, scan(/./x)
      end
    end

  end

  SYNTAX["ansic"] = AnsiC

end




