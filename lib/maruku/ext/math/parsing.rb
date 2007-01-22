module MaRuKu
	class MDDocument
		# Hash equation id (String) to equation element (MDElement)
		attr_accessor :eqid2eq
	end
end


	# At least one slash inside
	#RegInlineMath1 = /\$([^\$]*[\\][^\$]*)\$/
	# No spaces around the delimiters
	#RegInlineMath2 = /\$([^\s\$](?:[^\$]*[^\s\$])?)\$/
	#RegInlineMath = Regexp::union(RegInlineMath1,RegInlineMath2)

	# Everything goes; takes care of escaping the "\$" inside the expression
	RegInlineMath = /\${1}((?:[^\$]|\\\$)+)\$/
	
	MaRuKu::In::Markdown::
	register_span_extension(:chars => ?$, :regexp => RegInlineMath) do 
		|doc, src, con|
		if m = src.read_regexp(RegInlineMath)
			math = m.captures.compact.first
			con.push doc.md_inline_math(math)
			true
		else
			#puts "not math: #{src.cur_chars 10}"
			false
		end
	end
	
	EquationStart = /^[ ]{0,3}(?:\\\[|\$\$)(.*)$/
	
	EqLabel = /(?:\((\w+)\))/
	OneLineEquation = /^[ ]{0,3}(?:\\\[|\$\$)(.*)(?:\\\]|\$\$)\s*#{EqLabel}?\s*$/
	EquationEnd = /^(.*)(?:\\\]|\$\$)\s*#{EqLabel}?\s*$/

	MaRuKu::In::Markdown::
	register_block_extension(:regexp  => EquationStart) do |doc, src, con|
#		puts "Equation :#{self}"
		first = src.shift_line
		if first =~ OneLineEquation
			math = $1
			label = $2 
			con.push doc.md_equation($1, $2)
		else
			first =~ EquationStart
			math = $1
			label = nil
			while true
				if not src.cur_line
					maruku_error "Stream finished while reading equation\n\n"+
					add_tabs(math,1,'$> '), src, con
					break
				end
				line = src.shift_line
				if line =~ EquationEnd
					math += $1 + "\n"
					label = $2 if $2
					break
				else
					math += line + "\n"
				end
			end
			con.push doc.md_equation(math, label)
		end
		true
	end
		
		
	# This adds support for \eqref
	RegEqrefLatex = /\\eqref\{(\w+)\}/
	RegEqPar = /\(eq:(\w+)\)/
	RegEqref = Regexp::union(RegEqrefLatex, RegEqPar)
	
	MaRuKu::In::Markdown::
	register_span_extension(:chars => [?\\, ?(], :regexp => RegEqref) do 
		|doc, src, con|
		eqid = src.read_regexp(RegEqref).captures.compact.first
		r = doc.md_el(:eqref, [], meta={:eqid=>eqid})
		con.push r
	 	true 
	end
