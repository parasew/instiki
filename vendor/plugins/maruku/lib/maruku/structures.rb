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
  # Rather than having a separate class for every possible element,
  # Maruku has a single {MDElement} class
  # that represents eveything in the document (paragraphs, headers, etc).
  # The type of each element is available via \{#node\_type}.
  class MDElement
    # The type of this node (e.g. `:quote`, `:image`, `:abbr`).
    # See {Helpers} for a list of possible values.
    #
    # @return [Symbol]
    attr_accessor :node_type

    # The child nodes of this element.
    #
    # @return [Array<String or MDElement>]
    attr_accessor :children

    # An attribute list. May not be nil.
    #
    # @return [AttributeList]
    attr_accessor :al

    # The processed attributes.
    #
    # For the {Maruku document root},
    # this contains properties listed
    # at the beginning of the document.
    # The properties will be downcased and any spaces
    # will be converted to underscores.
    # For example, if you write in the source document:
    #
    #     !!!text
    #     Title: test document
    #     My property: value
    #
    #     content content
    #
    # Then \{#attributes} will return:
    #
    #     {:title => "test document", :my_property => "value"}
    #
    # @return [{Symbol => String}]
    attr_accessor :attributes

    # The root element of the document
    # to which this element belongs.
    #
    # @return [Maruku]
    attr_accessor :doc

    def initialize(node_type = :unset, children = [], meta = {}, al = nil)
      self.children = children
      self.node_type = node_type
      self.attributes = {}

      meta.each do |symbol, value|
        self.instance_eval <<RUBY
          def #{symbol}; @#{symbol}; end
          def #{symbol}=(val); @#{symbol} = val; end
RUBY
        self.send "#{symbol}=", value
      end

      self.al = al || AttributeList.new
      self.meta_priv = meta
    end

    # @private
    attr_accessor :meta_priv

    def ==(o)
      o.is_a?(MDElement) &&
        self.node_type == o.node_type &&
        self.meta_priv == o.meta_priv &&
        self.children == o.children
    end
  end

  # This represents the whole document and holds global data.
  class MDDocument
    # @return [{String => {:url => String, :title => String}}]
    attr_accessor :refs

    # @return [{String => MDElement}]
    attr_accessor :footnotes

    # @return [{String => String}]
    attr_accessor :abbreviations

    # Attribute definition lists.
    #
    # @return [{String => AttributeList}]
    attr_accessor :ald

    # The order in which footnotes are used. Contains the id.
    #
    # @return [Array<String>]
    attr_accessor :footnotes_order

    # @return [Array<String>]
    attr_accessor :latex_required_packages

    # @return [{String => {String => MDElement}}]
    attr_accessor :refid2ref

    # A counter for generating unique IDs [Integer]
    attr_accessor :id_counter

    def initialize(s=nil)
      super(:document)

      self.doc = self
      self.refs = {}
      self.footnotes = {}
      self.footnotes_order = []
      self.abbreviations = {}
      self.ald = {}
      self.latex_required_packages = []
      self.id_counter = 0

      parse_doc(s) if s
    end
  end
end
