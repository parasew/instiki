# fenced_code.rb -- Maruku extension for fenced code blocks
#
# Copyright (C) 2009 Jason R. Blevins
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# Fenced code blocks begin with three or more tildes and are terminated
# by a closing line with at least as many tildes as the opening line.
# Optionally, an attribute list may appear at the end of the opening
# line.  For example:
#
# ~~~~~~~~~~~~~ {: lang=ruby }
# puts 'Hello world'
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~

OpenFence = /^(~~~+?)\s*(\{([^{}]*?|".*?"|'.*?')*\})?\s*$/

MaRuKu::In::Markdown::register_block_extension(
	:regexp  => OpenFence,
	:handler => lambda { |doc, src, context|

	first = src.shift_line
	first =~ OpenFence
	close_fence = /^#{$1}~*$/
	ial = $2

	lines = []

	# read until CloseFence
	while src.cur_line
		if src.cur_line =~ close_fence
			src.shift_line
			break
		else
			lines.push src.shift_line
		end
	end

	ial = nil unless (ial && ial.size > 0)
	al = nil

	if ial =~ /^\{(.*?)\}\s*$/
		inside = $1
		cs = MaRuKu::In::Markdown::SpanLevelParser::CharSource
		al = ial &&
			doc.read_attribute_list(cs.new(inside),
				its_context=nil, break_on=[nil])
	end

	source = lines.join("\n")
	context.push doc.md_codeblock(source, al)
	true
})
