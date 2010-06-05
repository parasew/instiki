require 'maruku/ext/math/latex_fix'

module MaRuKu
  module Out
    module Latex
      def to_latex_inline_math
        fix_latex("$#{self.math.strip}$")
      end

      def to_latex_equation
        if self.label
          fix_latex("\\begin{equation}\n#{self.math.strip}\n\\label{#{self.label}}\\end{equation}\n")
        else
          fix_latex("\\begin{displaymath}\n#{self.math.strip}\n\\end{displaymath}\n")
        end
      end

      def to_latex_eqref
        "\\eqref{#{self.eqid}}"
      end

      def to_latex_divref
        "\\ref{#{self.refid}}"
      end

      private

      def fix_latex(str)
        return str unless self.get_setting(:html_math_engine) == 'itex2mml'
        s = str.gsub("\\mathop{", "\\operatorname{")
        s.gsub!(/\\begin\{svg\}.*?\\end\{svg\}/m, " ")
        s.gsub("\\space{", "\\itexspace{")
      end
    end
  end
end
