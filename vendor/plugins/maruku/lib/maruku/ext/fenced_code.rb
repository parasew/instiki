# fenced_code.rb -- Maruku extension for fenced code blocks
#
# Copyright (C) 2009 Jason R. Blevins
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#  * Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
#  * Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
#  * Neither the names of the copyright holders nor the names of any
#    contributors may be used to endorse or promote products derived from this
#    software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
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
