
# run this as:
# ruby -I../../lib use_itex.rb < private.txt

require 'maruku'

module MaRuKu; module Out; module HTML
	
	def to_html_inline_math_itex
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
	
	def to_html_equation_itex
		return to_html_inline_math_itex
	end

end end end

MaRuKu::Globals[:html_math_engine] = 'itex'

doc = Maruku.new($stdin.read, {:on_error => :raise})

File.open('output.xhtml','w') do |f|
	f.puts doc.to_html_document
end

