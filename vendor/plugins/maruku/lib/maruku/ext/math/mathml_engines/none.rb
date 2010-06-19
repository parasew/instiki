module MaRuKu; module Out; module HTML

  require 'maruku/string_utils'

	def convert_to_mathml_none(kind, tex)
		# You can: either return a REXML::Element
		#    return Element.new 'div'    
		# or return an empty array on error
		#    return []  
		# or have a string parsed by REXML:
		mathml = "<code>#{html_escape(tex)}</code>"
		return Document.new(mathml).root
	end

	def convert_to_png_none(kind, tex)
		return nil
	end


end end end

