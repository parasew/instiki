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


module MaRuKu
	
Globals = {
	:unsafe_features => false,
	
	:debug_keep_ials => false,
	
	:maruku_signature => false,
	:code_background_color => '#fef',
	:code_show_spaces => false,
	:html_math_engine => 'itex2mml', #ritex, itex2mml, none
	:html_use_syntax => false,
	:on_error => :warning
}

class MDElement
	def get_setting(sym)
		if self.attributes.has_key?(sym) then
			return self.attributes[sym]
		elsif self.doc && self.doc.attributes.has_key?(sym) then
			return self.doc.attributes[sym]
		elsif MaRuKu::Globals.has_key?(sym)
			return MaRuKu::Globals[sym]
		else
			$stderr.puts "Bug: no default for #{sym.inspect}"
			nil
		end
	end
end

end
