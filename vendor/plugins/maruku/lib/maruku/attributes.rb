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


class String
	def quote_if_needed
		if /[\s\'\"]/.match self
			inspect
		else
			self
		end
	end
end

module MaRuKu; 
	MagicChar = ':'
	
	class AttributeList < Array
		
		# An attribute list becomes 
		# {#id .cl key="val" ref}
		# [ [:id, 'id'], [:class, 'id'], ['key', 'val'], [ :ref, 'ref' ]]

		private :push
		
		def push_key_val(key, val); 
			raise "Bad #{key.inspect}=#{val.inspect}" if not key and val
			push [key, val] 
		end
		def push_ref(ref_id);       
			
			raise "Bad :ref #{ref_id.inspect}" if not ref_id
			push [:ref, ref_id+""] 

#			p "Now ", self ########################################
		end
		def push_class(val);        
			raise "Bad :id #{val.inspect}" if not val
			push [:class,  val] 
		end
		def push_id(val);           
			raise "Bad :id #{val.inspect}" if not val
			push [:id,  val] 
		end
		
		def to_s
			map do |k,v|
				case k
				when :id;    "#" + v.quote_if_needed
				when :class; "." + v.quote_if_needed
				when :ref;    v.quote_if_needed
				else k.quote_if_needed + "=" + v.quote_if_needed
				end
			end . join(' ')
		end
		alias to_md to_s 
	end
	
end

module MaRuKu; module In; module Markdown; module SpanLevelParser
	
	def md_al(s=[]); AttributeList.new(s) end

	# returns nil or an AttributeList
	def read_attribute_list(src, con, break_on_chars)
		
		separators = break_on_chars + [?=,?\ ,?\t]
		escaped = Maruku::EscapedCharInQuotes
			
		al = AttributeList.new
		while true
			src.consume_whitespace
			break if break_on_chars.include? src.cur_char
	
			case src.cur_char
			when nil 
				maruku_error "Attribute list terminated by EOF:\n "+
				             "#{al.inspect}" , src, con
				tell_user "I try to continue and return partial attribute list:\n"+
					al.inspect
				break
			when ?=     # error
				maruku_error "In attribute lists, cannot start identifier with `=`."
				tell_user "I try to continue"
				src.ignore_char
			when ?#     # id definition
				src.ignore_char
				if id = read_quoted_or_unquoted(src, con, escaped, separators)
					al.push_id id
				else
					maruku_error 'Could not read `id` attribute.', src, con
					tell_user 'Trying to ignore bad `id` attribute.'
				end
			when ?.     # class definition
				src.ignore_char
				if klass = read_quoted_or_unquoted(src, con, escaped, separators)
					al.push_class klass
				else
					maruku_error 'Could not read `class` attribute.', src, con
					tell_user 'Trying to ignore bad `class` attribute.'
				end
			else
				if key = read_quoted_or_unquoted(src, con, escaped, separators)
					if src.cur_char == ?=
						src.ignore_char # skip the =
						if val = read_quoted_or_unquoted(src, con, escaped, separators)
							al.push_key_val(key, val)
						else
							maruku_error "Could not read value for key #{key.inspect}.",
								src, con
							tell_user "Ignoring key #{key.inspect}."
						end
					else
						al.push_ref key
					end
				else
					maruku_error 'Could not read key or reference.'
				end
			end # case
		end # while true
		al
	end
	
	
	# We need a helper
	def is_ial(e); e.kind_of? MDElement and e.node_type == :ial end

	def merge_ial(elements, src, con)	

		# Apply each IAL to the element before
		elements.each_with_index do |e, i| 
		if is_ial(e) && i>= 1 then
			before = elements[i-1]
			after = elements[i+1]
			if before.kind_of? MDElement
				before.al = e.ial
			elsif after.kind_of? MDElement
				after.al = e.ial
			else
				maruku_error "It is not clear to me what element this IAL {:#{e.ial.to_md}} \n"+
				"is referring to. The element before is a #{before.class.to_s}, \n"+
				"the element after is a #{after.class.to_s}.\n"+
				"\n before: #{before.inspect}"+
				"\n after: #{after.inspect}",
				src, con
				# xxx dire se c'è empty vicino
			end
		end 
		end
		
		if not Globals[:debug_keep_ials]
			elements.delete_if {|x| is_ial(x) unless x == elements.first} 
		end
	end
		
end end end end 
#module MaRuKu; module In; module Markdown; module SpanLevelParser
