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


module MaRuKu
  class MDElement
    def inspect(compact=true)
      if compact
        i2 = inspect2
        return i2 if i2
      end

      # Make sure the attributes are lexically ordered
      meta_ordered = "{" + @meta_priv.keys.
        map {|x| x.to_s}.sort.map {|x| x.to_sym}.
        map {|k| k.inspect + "=>" + @meta_priv[k].inspect}.
        join(',') + "}"

      "md_el(%s,%s,%s,%s)" % [
        self.node_type.inspect,
        children_inspect(compact),
        meta_ordered,
        self.al.inspect
      ]
    end

    def children_inspect(compact=true)
      kids = @children.map {|x| x.is_a?(MDElement) ? x.inspect(compact) : x.inspect}
      comma = kids.join(", ")

      return "[#{comma}]" if comma.size < 70
      "[\n\t#{kids.join(",\n\t")}\n]"
    end

  end
end
