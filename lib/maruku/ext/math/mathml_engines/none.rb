module MaRuKu; module Out; module HTML

	def to_html_inline_math_none
		# You can: either return a REXML::Element
		#    return Element.new 'div'    
		# or return an empty array on error
		#    return []  
		# or have a string parsed by REXML:
		tex = self.math
		tex.gsub!('&','&amp;')
		mathml = "<code>#{tex}</code>"
		return Document.new(mathml).root
	end

	def to_html_equation_none
		return to_html_inline_math_none
	end

end end end

