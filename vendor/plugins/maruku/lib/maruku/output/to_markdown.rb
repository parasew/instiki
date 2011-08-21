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
	# XXX: markdown escaping
	def to_md(c=nil)
		to_s
	end
	
	# " andrea censi " => [" andrea ", "censi "]
	def mysplit
        res = split.map{|x| x+" "}
        if self[0] == 32
             res[0] = " " + res[0]
        end
        res
	end
end


module MaRuKu; module Out; module Markdown 
	
	DefaultLineLength = 40
	
	def to_md(context={})
		children_to_md(context)
	end
	
	def to_md_paragraph(context)
		line_length = context[:line_length] || DefaultLineLength
		wrap(@children, line_length, context)+"\n"
	end

    def to_md_header(context)
        pounds = "#" * @level
    "#{pounds} #{children_to_md(context)} #{pounds}\n\n"
    end

    def to_md_inline_code(context)
    "`#{@raw_code}`"
     end

     def to_md_code(context)
        @raw_code.split("\n").collect { |line| "     " + line}.join("\n") + "\n"
     end

    def to_md_quote(context)
        line_length = (context[:line_length] || DefaultLineLength) - 2
         wrap(@children, line_length, context).split(/\n/).collect { |line| "> " + line}.join("\n") + "\n"
    end

    def to_md_hrule(context)
        "* * *"
    end

    def to_md_emphasis(context)
        "*#{children_to_md(context)}*"
    end

    def to_md_strong(context)
         "**#{children_to_md(context)}**"
     end

    def to_md_immediate_link(context)
        "<#{@url}>"
    end

    def to_md_email_address(context)
        "<#{@email}>"
     end

    def to_md_entity(context)
        "&#{@entity_name};"
    end

    def to_md_linebreak(context)
        "\n"
    end

    def to_md_paragraph(context)
        line_length = context[:line_length] || DefaultLineLength
         wrap(@children, line_length, context)+"\n"
     end

    def to_md_im_link(context)
         "[#{children_to_md(context)}](#{@url}#{" #{@title}" if @title})"
    end

    def to_md_link(context)
        "[#{children_to_md(context)}][#{@ref_id}]"
    end

    def to_md_im_image(context)
     "![#{children_to_md(context)}](#{@url}#{" #{@title}" if @title})"
     end
    def to_md_image(context)
        "![#{children_to_md(context)}][#{@ref_id}]"
    end

    def to_md_ref_definition(context)
        "[#{@ref_id}] #{@url}#{" #{@title}" if @title}"
    end

    def to_md_li_span(context)
		len = (context[:line_length] || DefaultLineLength) - 2
#		s = wrap(@children, len-2, context).rstrip.gsub(/^/, '  ')
#		s[0] = ?*
#		s + "\n"
        s = "* " + wrap(@children, len-2, context).rstrip + "\n"
	end
	
	def to_md_abbr_def(context)
		"*[#{self.abbr}]: #{self.text}\n"
	end
	
	def to_md_ol(context)
		len = (context[:line_length] || DefaultLineLength) - 2
		md = ""
		self.children.each_with_index do |li, i|
#			s = (w=wrap(li.children, len-2, context)).rstrip.gsub(/^/, '    ')+"\n"
#			s[0,4] = "#{i+1}.  "[0,4]
#			puts w.inspect
            s = "#{i+1}. " + (w=wrap(li.children, len-2, context)).rstrip + "\n"
			md += s
		end
		md + "\n"
	end

	def to_md_ul(context)
		len = (context[:line_length] || DefaultLineLength) - 2
		md = ""
		self.children.each_with_index do |li, i|
			w = wrap(li.children, len-2, context)
			s = "- " + w
#			puts "W: "+ w.inspect
	#		s = add_indent(w)
#			puts "S: " +s.inspect
	#		s[0,1] = "-"
			md += s
		end
		md + "\n"
	end
	
	def add_indent(s,char="    ")
		t = s.split("\n").map{|x| char+x }.join("\n")
		s << ?\n if t[-1] == ?\n
		s
	end
	
	# Convert each child to html
	def children_to_md(context)
		array_to_md(@children, context)
	end
	
	def wrap(array, line_length, context)
		out = ""
		line = ""
		array.each do |c|
			if c.kind_of?(MDElement) &&  c.node_type == :linebreak
				out << line.strip << "  \n"; line="";
				next
			end
		
			pieces =
			if c.kind_of? String
				c.to_md.mysplit
            elsif c.kind_of?(MDElement)
                method = "to_md_#{c.node_type}"
                method = "to_md" unless c.respond_to?(method)
                [c.send(method, context)].flatten
			else
				[c.to_md(context)].flatten
			end
		
	#			puts "Pieces: #{pieces.inspect}"
			pieces.each do |p|
				if p.size + line.size > line_length
					out << line.strip << "\n"; 
					line = ""
				end
				line << p
			end
		end
		out << line.strip << "\n" if line.size > 0
		out << ?\n if not out[-1] == ?\n
		out
	end


	def array_to_md(array, context, join_char='')
		e = []
		array.each do |c|
			method = c.kind_of?(MDElement) ? 
			   "to_md_#{c.node_type}" : "to_md"
			
			if not c.respond_to?(method)
				#raise "Object does not answer to #{method}: #{c.class} #{c.inspect[0,100]}"
#				tell_user "Using default for #{c.node_type}"
				method = 'to_md'
			end
			
#			puts "#{c.inspect} created with method #{method}"
			h =  c.send(method, context)
			
			if h.nil?
				raise "Nil md for #{c.inspect} created with method #{method}"
			end
			
			if h.kind_of?Array
				e = e + h
			else
				e << h
			end
		end
		e.join(join_char)
	end
	
end end end

module MaRuKu; class MDDocument
	alias old_md to_md
	def to_md(context={})
		s = old_md(context)
#		puts s
		s
	end	
end end
