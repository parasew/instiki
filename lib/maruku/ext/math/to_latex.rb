
module MaRuKu; module Out; module Latex

	def to_latex_inline_math
		"$#{self.math.strip}$"
	end

	def to_latex_equation
		if self.label
			l =  "\\label{#{self.label}}"
			"\\begin{equation}\n#{self.math.strip}\n#{l}\\end{equation}\n"
		else
			"\\begin{displaymath}\n#{self.math.strip}\n\\end{displaymath}\n"
		end
	end
	
	def to_latex_eqref
		"\\eqref{#{self.eqid}}"
	end

end end end