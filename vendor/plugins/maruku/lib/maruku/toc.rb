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
  # A section in the table of contents of a document.
  class Section
    # The depth of the section (0 for toplevel).
    #
    # Equivalent to `header_element.level`.
    #
    # @return [Fixnum]
    attr_accessor :section_level

    # The nested section number, e.g. `[1, 2, 5]` for Section 1.2.5.
    #
    # @return [Array<Fixnum>]
    attr_accessor :section_number

    # The `:header` node for this section.
    # The value of `meta[:section]` for the header will be this node.
    #
    # @return [MDElement]
    attr_accessor :header_element

    # The immediate child nodes of this section.
    #
    # @todo Why does this never contain Strings?
    #
    # @return [Array<MDElement>]
    attr_accessor :immediate_children

    # The subsections of this section.
    #
    # @return [Array<Section>]
    attr_accessor :section_children

    def initialize
      @immediate_children = []
      @section_children = []
    end

    def inspect(indent = 1)
      s = ""

      if @header_element
        s << "\_" * indent <<
          "(#{@section_level})>\t #{@section_number.join('.')} : " <<
          @header_element.children_to_s <<
          " (id: '#{@header_element.attributes[:id]}')\n"
      else
        s << "Master\n"
      end
      @section_children.each {|c| s << c.inspect(indent+1)}

      s
    end

    # Assign \{#section\_number section numbers}
    # to this section and its children.
    # This also assigns the section number attribute
    # to the sections' headers.
    #
    # This should only be called on the root section.
    #
    # @overload def numerate
    def numerate(a = [])
      self.section_number = a
      section_children.each_with_index {|c, i| c.numerate(a + [i + 1])}
      if h = self.header_element
        h.attributes[:section_number] = self.section_number
      end
    end

    include REXML

    # Returns an HTML representation of the table of contents.
    #
    # This should only be called on the root section.
    def to_html
      div = Element.new 'div'
      div.attributes['class'] = 'maruku_toc'
      div << _to_html
      div
    end

    # Returns a LaTeX representation of the table of contents.
    #
    # This should only be called on the root section.
    def to_latex
      _to_latex + "\n\n"
    end

    protected

    def _to_html
      ul = Element.new 'ul'
      # let's remove the bullets
      ul.attributes['style'] = 'list-style: none;'
      @section_children.each do |c|
        li = Element.new 'li'
        if span = c.header_element.render_section_number
          li << span
        end

        a = c.header_element.wrap_as_element('a')
        a.delete_attribute 'id'
        a.attributes['href'] = "##{c.header_element.attributes[:id]}"

        li << a
        li << c._to_html if c.section_children.size > 0
        ul << li
      end
      ul
    end

    def _to_latex
      s = ""
      @section_children.each do |c|
        s << "\\noindent"
        if number = c.header_element.section_number
          s << number
        end
        id = c.header_element.attributes[:id]
        text = c.header_element.children_to_latex
        s << "\\hyperlink{#{id}}{#{text}}"
        s << "\\dotfill \\pageref*{#{id}} \\linebreak\n"
        s << c._to_latex if c.section_children.size > 0
      end
      s
    end
  end

  class MDDocument
    # The table of contents for the document.
    #
    # @return [Section]
    attr_accessor :toc

    def create_toc
      each_element(:header) {|h| h.attributes[:id] ||= h.generate_id}

      stack = []

      # The root section
      s = Section.new
      s.section_level = 0

      stack.push s

      # TODO: Clean up the logic here once we have better tests
      i = 0
      while i < @children.size
        while i < @children.size
          if @children[i].node_type == :header
            level = @children[i].level
            break if level <= stack.last.section_level + 1
          end

          stack.last.immediate_children.push @children[i]
          i += 1
        end

        break if i >= @children.size

        header = @children[i]
        level = header.level

        if level > stack.last.section_level
          # this level is inside

          s2 = Section.new
          s2.section_level = level
          s2.header_element = header
          header.instance_variable_set :@section, s2

          stack.last.section_children.push s2
          stack.push s2

          i += 1
        elsif level == stack.last.section_level
          # this level is a sibling
          stack.pop
        else
          # this level is a parent
          stack.pop
        end
      end

      # If there is only one big header, then assume it is the master
      s = s.section_children.first if s.section_children.size == 1

      # Assign section numbers
      s.numerate

      s
    end
  end
end
