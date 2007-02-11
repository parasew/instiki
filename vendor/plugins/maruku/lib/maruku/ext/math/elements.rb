module MaRuKu; class MDElement
	
	def md_inline_math(math)
		self.md_el(:inline_math, [], meta={:math=>math})
	end

	def md_equation(math, label=nil)
		reglabel= /\\label\{(\w+)\}/
		if math =~ reglabel
			label = $1
			math.gsub!(reglabel,'')
		end
#		puts "Found label = #{label} math #{math.inspect} "
		num = nil
		if label && @doc #take number
			@doc.eqid2eq ||= {}	
			num = @doc.eqid2eq.size + 1
		end
		e = self.md_el(:equation, [], meta={:math=>math, :label=>label,:num=>num})
		if label && @doc #take number
			@doc.eqid2eq[label] = e
		end
		e
	end

end end