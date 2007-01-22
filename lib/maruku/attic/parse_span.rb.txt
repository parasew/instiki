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




#  NOTE: this is the old span-level regexp-based parser.
#
#  The new parser is a real parser and is defined with functions in parse_span_better.rb
#  The new parser is faster, handles syntax errors, but it's absolutely not readable.
#
#  Also, regexp parsers simply CANNOT handle inline HTML properly.



# There are two black-magic methods `match_couple_of` and `map_match`,
# defined at the end of the file, that make the function 
# `parse_lines_as_span` so elegant.

class Maruku

	# Takes care of all span-level formatting, links, images, etc.
	#
	# Lines must not contain block-level elements.
	def parse_lines_as_span(lines)
		
		# first, get rid of linebreaks
		res = resolve_linebreaks(lines)

		span = MDElement.new(:dummy, res)

		# encode all escapes
		span.replace_each_string { |s| s.escape_md_special }


# The order of processing is significant: 
# 1. inline code
# 2. immediate links
# 3. inline HTML 
# 4. everything else

		# search for ``code`` markers
		span.match_couple_of('``') { |children, match1, match2| 
			e = create_md_element(:inline_code)
			# this is now opaque to processing
			e.meta[:raw_code] = children.join('').it_was_a_code_block
			e
		}

		# Search for `single tick`  code markers
		span.match_couple_of('`') { |children, match1, match2|
			e = create_md_element(:inline_code)
			# this is now opaque to processing
			e.meta[:raw_code] = children.join('').it_was_a_code_block
			# this is now opaque to processing
			e
		}
		
		# Detect any immediate link: <http://www.google.com>
		# we expect an http: or something: at the beginning
		span.map_match( /<(\w+:[^\>]+)>/) { |match| 
			url = match[1]
			
			e = create_md_element(:immediate_link, [])
			e.meta[:url] = url
			e
		}
		
		# Search for inline HTML (the support is pretty basic for now)
		
		# this searches for a matching block
		inlineHTML1 = %r{
			(   # put everything in 1 
			<   # open
			(\w+) # opening tag in 2
			>   # close
			.*  # anything
			</\2> # match closing tag
			)
		}x

		# this searches for only one block
		inlineHTML2 = %r{
			(   # put everything in 1 
			<   # open
			\w+ # 
			    # close
			[^<>]*  # anything except
			/> # closing tag
			)
		}x
		
		for reg in [inlineHTML1, inlineHTML2]
			span.map_match(reg) { |match| 
				raw_html = match[1]
				convert_raw_html_in_list(raw_html)
			}
		end
		
		# Detect footnotes references: [^1]
		span.map_match(/\[(\^[^\]]+)\]/) { |match| 
			id = match[1].strip.downcase
			e = create_md_element(:footnote_reference)
			e.meta[:footnote_id] = id
			e
		}

		# Detect any image like ![Alt text][url]
		span.map_match(/\!\[([^\]]+)\]\s?\[([^\]]*)\]/) { |match|
			alt = match[1]
			id = match[2].strip.downcase
			
			if id.size == 0
				id = text.strip.downcase
			end
			
			e = create_md_element(:image)
			e.meta[:ref_id] = id
			e
		}

		# Detect any immage with immediate url: ![Alt](url "title")
		# a dummy ref is created and put in the symbol table
		link1 = /!\[([^\]]+)\]\s?\(([^\s\)]*)(?:\s+["'](.*)["'])?\)/
		span.map_match(link1) { |match|
			alt = match[1]
			url = match[2]
			title = match[3]
			
			url = url.strip
			# create a dummy id
			id="dummy_#{@refs.size}"
			@refs[id] = {:url=>url, :title=>title}
			
			e = create_md_element(:image)
			e.meta[:ref_id] = id
			e
		}

		# an id reference: "[id]",  "[ id  ]"
		reg_id_ref = %r{
			\[ # opening bracket 
			([^\]]*) # 0 or more non-closing bracket (this is too permissive)
			\] # closing bracket
			}x
			
		
		# validates a url, only $1 is set to the url
 		reg_url = 
			/((?:\w+):\/\/(?:\w+:{0,1}\w*@)?(?:\S+)(?::[0-9]+)?(?:\/|\/([\w#!:.?+=&%@!\-\/]))?)/
		reg_url = %r{([^\s\]\)]+)}
		
		# A string enclosed in quotes.
		reg_title = %r{
			" # opening
			[^"]*   # anything = 1
			" # closing
			}x
		
		# [bah](http://www.google.com "Google.com"), 
		# [bah](http://www.google.com),
		# [empty]()
		reg_url_and_title = %r{
			\(  # opening
			\s* # whitespace 
			#{reg_url}?  # url = 1 might be  empty
			(?:\s+["'](.*)["'])? # optional title  = 2
			\s* # whitespace 
			\) # closing
		}x
		
		# Detect a link like ![Alt text][id]
		span.map_match(/\[([^\]]+)\]\s?\[([^\]]*)\]/) { |match|
			text = match[1]
			id = match[2].strip.downcase
			
			if id.size == 0
				id = text.strip.downcase
			end

			children = parse_lines_as_span(text)
			e = create_md_element(:link, children)
			e.meta[:ref_id] = id
			e
		}
		
		# Detect any immage with immediate url: ![Alt](url "title")
		# a dummy ref is created and put in the symbol table
		link1 = /!\[([^\]]+)\]\s?\(([^\s\)]*)(?:\s+["'](.*)["'])?\)/
		span.map_match(link1) { |match|
			text = match[1]
			children = parse_lines_as_span(text)
			
			url = match[2]
			title = match[3]
			
			url = url.strip
			# create a dummy id
			id="dummy_#{@refs.size}"
			@refs[id] = {:url=>url, :title=>title}
			@refs[id][:title] = title if title
			
			e = create_md_element(:link, children)
			e.meta[:ref_id] = id
			e
		}
		

		# Detect any link like [Google engine][google]
		span.match_couple_of('[',  # opening bracket
			%r{\]                   # closing bracket
			[ ]?                    # optional whitespace
			#{reg_id_ref} # ref id, with $1 being the reference 
			}x
				) { |children, match1, match2| 
			id = match2[1]
			id = id.strip.downcase
			
			if id.size == 0
				id = children.join.strip.downcase
			end
			
			e = create_md_element(:link, children)
			e.meta[:ref_id] = id
			e
		}

		# Detect any link with immediate url: [Google](http://www.google.com)
		# XXX Note that the url can be empty: [Empty]()
		# a dummy ref is created and put in the symbol table
		span.match_couple_of('[',  # opening bracket
				%r{\]                   # closing bracket
				[ ]?                    # optional whitespace
				#{reg_url_and_title}    # ref id, with $1 being the url and $2 being the title
				}x
					) { |children, match1, match2| 
			
			url   = match2[1]
			title = match2[3] # XXX? Is it a bug? I would use [2]
			 
			# create a dummy id
			id="dummy_#{@refs.size}"
			@refs[id] = {:url=>url}
			@refs[id][:title] = title if title

			e = create_md_element(:link, children)
			e.meta[:ref_id] = id
			e
		}

		# Detect an email address <andrea@invalid.it>
		span.map_match(EMailAddress) { |match| 
			email = match[1]
			e = create_md_element(:email_address, [])
			e.meta[:email] = email
			e
		}
		
		# Detect HTML entitis
		span.map_match(/&([\w\d]+);/) { |match| 
			entity_name = match[1]

			e = create_md_element(:entity, [])
			e.meta[:entity_name] = entity_name
			e
		}


		# And now the easy stuff

		# search for ***strong and em***
		span.match_couple_of('***') { |children,m1,m2|  
			create_md_element(:strong, [create_md_element(:emphasis, children)] ) }

		span.match_couple_of('___') { |children,m1,m2|  
			create_md_element(:strong, [create_md_element(:emphasis, children)] ) }
	
		# search for **strong**
		span.match_couple_of('**') { |children,m1,m2|  create_md_element(:strong,   children) }

		# search for __strong__
		span.match_couple_of('__') { |children,m1,m2|  create_md_element(:strong,   children) }

		# search for *emphasis*
		span.match_couple_of('*')  { |children,m1,m2|  create_md_element(:emphasis, children) }
		
		# search for _emphasis_
		span.match_couple_of('_')  { |children,m1,m2|  create_md_element(:emphasis, children) }
		
		# finally, unescape the special characters
		span.replace_each_string { |s|  s.unescape_md_special}
		
		span.children
	end
	
	# returns array containing Strings or :linebreak elements
	def resolve_linebreaks(lines)
		res = []
		s = ""
		lines.each do |l| 
			s += (s.size>0 ? " " : "") + l.strip
			if force_linebreak?(l)
				res << s
				res << create_md_element(:linebreak)
				s = ""
			end
		end
		res << s if s.size > 0
		res
	end

	# raw_html is something like 
	#  <em> A</em> dopwkk *maruk* <em>A</em>  
	def convert_raw_html_in_list(raw_html)
		e = create_md_element(:raw_html)
		e.meta[:raw_html]  = raw_html
		begin
			e.meta[:parsed_html] = Document.new(raw_html)
		rescue 
			$stderr.puts "convert_raw_html_in_list Malformed HTML:\n#{raw_html}"
		end
		e
	end

end

# And now the black magic that makes the part above so elegant
class MDElement	
	
	# Try to match the regexp to each string in the hierarchy
	# (using `replace_each_string`). If the regexp match, eliminate
	# the matching string and substitute it with the pre_match, the
	# result of the block, and the post_match
	#
	#   ..., matched_string, ... -> ..., pre_match, block.call(match), post_match
	#
	# the block might return arrays.
	#
	def map_match(regexp, &block)
		replace_each_string { |s| 
			processed = []
			while (match = regexp.match(s))
				# save the pre_match
				processed << match.pre_match if match.pre_match && match.pre_match.size>0
				# transform match
				result = block.call(match)
				# and append as processed
				[*result].each do |e| processed << e end
				# go on with the rest of the string
				s = match.post_match 
			end
			processed << s if s.size > 0
			processed
		}
	end
	
	# Finds couple of delimiters in a hierarchy of Strings and MDElements
	#
	# Open and close are two delimiters (like '[' and ']'), or two Regexp.
	#
	# If you don't pass close, it defaults to open.
	#
	# Each block is called with |contained children, match1, match2|
	def match_couple_of(open, close=nil, &block)
		close = close || open
		 open_regexp =  open.kind_of?(Regexp) ?  open : Regexp.new(Regexp.escape(open))
		close_regexp = close.kind_of?(Regexp) ? close : Regexp.new(Regexp.escape(close))
		
		# Do the same to children first
		for c in @children; if c.kind_of? MDElement
			c.match_couple_of(open_regexp, close_regexp, &block)
		end end
		
		processed_children = []
		
		until @children.empty?
			c = @children.shift
			if c.kind_of? String
				match1 = open_regexp.match(c)
				if not match1
					processed_children << c
				else # we found opening, now search closing
#					puts "Found opening (#{marker}) in #{c.inspect}"
					# pre match is processed
					processed_children.push match1.pre_match if 
						match1.pre_match && match1.pre_match.size > 0
					# we will process again the post_match
					@children.unshift match1.post_match if 
						match1.post_match && match1.post_match.size>0
					
					contained = []; found_closing = false
					until @children.empty?  || found_closing
						c = @children.shift
						if c.kind_of? String
							match2 = close_regexp.match(c)
							if not match2 
								contained << c
							else
								# we found closing
								found_closing = true
								# pre match is contained
								contained.push match2.pre_match if 
									match2.pre_match && match2.pre_match.size>0
								# we will process again the post_match
								@children.unshift match2.post_match if 
									match2.post_match && match2.post_match.size>0

								# And now we call the block
								substitute = block.call(contained, match1, match2) 
								processed_children  << substitute
								
#								puts "Found closing (#{marker}) in #{c.inspect}"
#								puts "Children: #{contained.inspect}"
#								puts "Substitute: #{substitute.inspect}"
							end
						else
							contained << c
						end
					end
					
					if not found_closing
						# $stderr.puts "##### Could not find closing for #{open}, #{close} -- ignoring"
						processed_children << match1.to_s
						contained.reverse.each do |c|
							@children.unshift c
						end
					end
				end
			else
				processed_children << c
			end
		end
		
		raise "BugBug" unless @children.empty?
		
		rebuilt = []
		# rebuild strings
		processed_children.each do |c|
			if c.kind_of?(String) && rebuilt.last && rebuilt.last.kind_of?(String)
				rebuilt.last << c
			else
				rebuilt << c
			end
		end
		@children = rebuilt
	end
end
