
module MaRuKu; module Out; module HTML

	def convert_to_mathml_itex2mml(tex, method)
		begin
			if not $itex2mml_parser
				require 'itextomml'
				$itex2mml_parser =  Itex2MML::Parser.new
			end
			
			mathml =  $itex2mml_parser.send(method, tex)
			doc = Document.new(mathml, {:respect_whitespace =>:all}).root
			return doc
		rescue LoadError => e
			maruku_error "Could not load package 'itex2mml'.\n"+
			"Please install it."
		rescue REXML::ParseException => e
			maruku_error "Invalid MathML TeX: \n#{add_tabs(tex,1,'tex>')}"+
				"\n\n #{e.inspect}"
		rescue 
			maruku_error "Could not produce MathML TeX: \n#{tex}"+
				"\n\n #{e.inspect}"
		end
		nil
	end
	
	def to_html_inline_math_itex2mml
		convert_to_mathml_itex2mml(self.math, :inline_filter) 
	end
	
	def to_html_equation_itex2mml
		convert_to_mathml_itex2mml(self.math, :block_filter)
	end

end end end
