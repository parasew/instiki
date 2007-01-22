module MaRuKu; module Out; module HTML
	def convert_to_mathml_ritex(tex)
		begin
			if not $ritex_parser
				require 'ritex'
			 	$ritex_parser = Ritex::Parser.new
			end
			
			mathml =  $ritex_parser.parse(tex.strip)
			doc = Document.new(mathml, {:respect_whitespace =>:all}).root
			return doc
		rescue LoadError => e
			maruku_error "Could not load package 'ritex'.\n"+
			"Please install it using:\n"+
			"   $ gem install ritex\n\n"+e.inspect
		rescue Racc::ParseError => e
			maruku_error "Could not parse TeX: \n#{tex}"+
				"\n\n #{e.inspect}"
		end
		nil
	end
	
	def to_html_inline_math_ritex
		tex = self.math
		mathml = convert_to_mathml_ritex(tex)
		return mathml || []
	end
	
	def to_html_equation_ritex
		tex = self.math
		mathml = convert_to_mathml_ritex(tex)
		return mathml || []
	end
end end end
