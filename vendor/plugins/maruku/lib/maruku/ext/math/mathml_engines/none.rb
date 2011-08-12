module MaRuKu; module Out; module HTML

  require 'maruku/string_utils'
  require 'nokogiri'

	def convert_to_mathml_none(kind, tex)
		# You can: either return a nokogiri::XML::Element
		# or return an empty array on error
		#    return []  
		mathml = "<code>#{html_escape(tex)}</code>"
		return Nokogiri::XML::Document.parse(mathml).root
	end

	def convert_to_png_none(kind, tex)
		return nil
	end


end end end

