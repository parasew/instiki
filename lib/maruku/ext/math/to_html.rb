
=begin maruku_doc
Attribute: html_math_engine
Scope: document, element
Output: html
Summary: Select the rendering engine for math.
Default: <?mrk Globals[:html_math_engine].to_s ?>

Select the rendering engine for math.

If you want to use your engine `foo`, then set:

	HTML math engine: foo
{:lang=markdown}

and then implement two functions:

	def to_html_inline_math_foo
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

	def to_html_equation_foo
		# same thing
		...
	end
{:lang=ruby}

=end

module MaRuKu; module Out; module HTML

	def to_html_inline_math
		s = get_setting(:html_math_engine)
		method = "to_html_inline_math_#{s}".to_sym
		if self.respond_to? method
			self.send method ||  to_html_equation_none
		else 
			puts "A method called #{method} should be defined."
			return []
		end
	end

	def add_class_to(el, cl)
		el.attributes['class'] = 
		if already = el.attributes['class']
			already + " " + cl
		else
			cl
		end
	end
	
	def to_html_equation
		s = get_setting(:html_math_engine)
		method = "to_html_equation_#{s}".to_sym
		if self.respond_to? method
			mathml = self.send(method) || to_html_equation_none
			div = create_html_element 'div'
			add_class_to(div, 'maruku-equation')
				if self.label # then numerate
					span = Element.new 'span'
					span.attributes['class'] = 'maruku-eq-number'
					num = self.num
					span << Text.new("(#{num})")
					div << span
					div.attributes['id'] = "eq:#{self.label}"
				end
				div << mathml
				
				source_div = Element.new 'div'
					add_class_to(source_div, 'maruku-eq-tex')
					code = to_html_equation_none	
					code.attributes['style'] = 'display: none'
				source_div << code
				div << source_div
			div
		else 
			puts "A method called #{method} should be defined."
			return []
		end
	end
	
	def to_html_eqref
		if eq = self.doc.eqid2eq[self.eqid]
			num = eq.num
			a = Element.new 'a'
			a.attributes['class'] = 'maruku-eqref'
			a.attributes['href'] = "#eq:#{self.eqid}"
			a << Text.new("(#{num})")
			a
		else
			maruku_error "Cannot find equation #{self.eqid.inspect}"
			Text.new "(#{self.eqid})"
		end
	end

	
end end end


