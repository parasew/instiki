require 'syntax'

module Syntax

  class Javascript < Tokenizer
    
    JAVASCRIPT_KEYWORDS =
      Set.new %w{abstract break case catch class const continue
         debugger default delete do else enum export extends
         final finally for function goto if implements
         import in instanceof interface native new
         package private protected public return
         static super switch synchronized this throw
         throws transient try typeof
         var void volatile while with} unless const_defined?(:JAVASCRIPT_KEYWORDS)

    JAVASCRIPT_PREDEFINED_TYPES =
      Set.new %w{boolean byte char double float int long short} unless const_defined?(:JAVASCRIPT_PREDEFINED_TYPES)

    JAVASCRIPT_PREDEFINED_CONSTANTS =
      %w{null true false} unless const_defined?(:JAVASCRIPT_PREDEFINED_CONSTANTS)
    
    def step
      case
      when scan(/\s+/)
        start_group :normal, matched
      when scan(/\\u[0-9a-f]{4}/i)
        start_group :unicode, matched
      when scan(/0[xX][0-9A-Fa-f]+/)
        start_group :hex, matched
      when scan(/(?:0[0-7]+)(?![89.eEfF])/)
        start_group :oct, matched
      when scan(/(?:\d+)(?![.eEfF])/)
        start_group :integer, matched
      when scan(/\d[fF]?|\d*\.\d+(?:[eE][+-]?\d+)?[fF]?|\d+[eE][+-]?\d+[fF]?/)
        start_group :float, matched
      when (scan(/"(?:[^"\\]|\\.)*"/) or scan(/'(?:[^'\\]|\\.)*'/) )
        start_group :string, matched
      when scan(/[a-z_$][a-z_\d]*/i)
        if JAVASCRIPT_KEYWORDS.include?( matched )
          start_group :keyword, matched
        elsif JAVASCRIPT_PREDEFINED_TYPES.include?( matched )
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

  SYNTAX["javascript"] = Javascript

end
