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
    # Iterates through each {MDElement} child node of this element.
    # This includes deeply-nested child nodes.
    # If `e_node_type` is specified, only yields nodes of that type.
    def each_element(e_node_type=nil, &block)
      @children.each do |c|
        next unless c.is_a? MDElement
        yield c if e_node_type.nil? || c.node_type == e_node_type
        c.each_element(e_node_type, &block)
      end
    end

    # Iterates through each String child node of this element,
    # replacing it with the result of the block.
    # This includes deeply-nested child nodes.
    #
    # This destructively modifies this node and its children.
    #
    # @todo Make this non-destructive
    def replace_each_string(&block)
      @children.map! do |c|
        next yield c unless c.is_a?(MDElement)
        c.replace_each_string(&block)
        c
      end.flatten!
    end
  end
end
