#--
#   Copyright (C) 2006  Andrea Censi  <andrea (at) rubyforge.org>
#
# This file is part of Maruku.
# 
#   Maruku is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
# 
#   Maruku is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
# 
#   You should have received a copy of the GNU General Public License
#   along with Maruku; if not, write to the Free Software
#   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#++


require 'rexml/document'

module MaRuKu; module Out; module Latex
	
	include REXML
	
	def to_latex_entity 
		MaRuKu::Out::Latex.need_entity_table
		
		entity_name = self.entity_name
	
		entity = ENTITY_TABLE[entity_name]
		if not entity
			maruku_error "I don't know how to translate entity '#{entity_name}' "+
			"to LaTeX."
			return ""
		end
		replace = entity.latex_string
		
		entity.latex_packages.each do |p|
			@doc.latex_require_package p
		end
		
#		if replace =~ /^\\/
#			replace = replace + " "
#		end
		
 		if replace
			return replace + "{}"
		else
			tell_user "Cannot translate entity #{entity_name.inspect} to LaTeX."
			return entity_name
		end
	end
	
	class LatexEntity
		attr_accessor :html_num
		attr_accessor :html_entity
		attr_accessor :latex_string
		attr_accessor :latex_packages
	end
	
	def Latex.need_entity_table
		Latex.init_entity_table if ENTITY_TABLE.empty?
	end
	
	# create hash @@entity_to_latex
	def Latex.init_entity_table
#		$stderr.write "Creating entity table.."
#		$stderr.flush
		doc = Document.new(File.read(File.dirname(__FILE__) + "/../../../data/entities.xml"))
		doc.elements.each("//char") do |c| 
			num =  c.attributes['num'].to_i
			name =  c.attributes['name']
			package =  c.attributes['package']
			
			convert =  c.attributes['convertTo']
			convert.gsub!(/@DOUBLEQUOT/,'"')
			convert.gsub!(/@QUOT/,"'")
			convert.gsub!(/@GT/,">")
			convert.gsub!(/@LT/,"<")
			convert.gsub!(/@AMP/,"&")
			convert.freeze
			
			e = LatexEntity.new
			e.html_num = num
			e.html_entity = name
			e.latex_string = convert
			e.latex_packages = package ? package.split : []
			
			ENTITY_TABLE[num] = e
			ENTITY_TABLE[name] = e
		end
#		$stderr.puts "..done."
	end
	
	ENTITY_TABLE = {}

end end end

