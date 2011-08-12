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

require 'nokogiri'

  # A collection of helper functions for creating Markdown elements.
  # They hide the particular internal representations.
  #
  # Always use these rather than creating an {MDElement} directly.
  module Helpers
    # @param children [Array<MDElement, String>]
    #   The child nodes.
    #   If the first child is a \{#md\_ial}, it's merged with `al`
    def md_el(node_type, children = [], meta = {}, al = nil)
      first = children.first
      if first.is_a?(MDElement) && first.node_type == :ial
        if al
          al += first.ial
        else
          al = first.ial
        end
        children.shift
      end

      e = MDElement.new(node_type, children, meta, al)
      e.doc = @doc
      e
    end

    def md_header(level, children, al = nil)
      md_el(:header, children, {:level => level}, al)
    end

    # Inline code
    def md_code(code, al = nil)
      md_el(:inline_code, [], {:raw_code => code}, al)
    end

    # Code block
    def md_codeblock(source, al = nil)
      md_el(:code, [], {:raw_code => source}, al)
    end

    def md_quote(children, al = nil)
      md_el(:quote, children, {}, al)
    end

    def md_li(children, want_my_par, al = nil)
      md_el(:li, children, {:want_my_paragraph => want_my_par}, al)
    end

    def md_footnote(footnote_id, children, al = nil)
      md_el(:footnote, children, {:footnote_id => footnote_id}, al)
    end

    def md_abbr_def(abbr, text, al = nil)
      md_el(:abbr_def, [], {:abbr => abbr, :text => text}, al)
    end

    def md_abbr(abbr, title)
      md_el(:abbr, [abbr], :title => title)
    end

    def md_html(raw_html, al = nil)
      e = md_el(:raw_html, [], :raw_html => raw_html)
      begin
        e.instance_variable_set("@parsed_html",
          Nokogiri::XML::Document.parse("<marukuwrap>#{raw_html.strip}</marukuwrap>"))
      rescue Nokogiri::XML::Document.errors => ex
        e.instance_variable_set "@parsed_html", nil
        maruku_recover <<ERR
Nokogiri cannot parse this block of HTML/XML:
#{raw_html.gsub(/^/, '|').rstrip}
#{ex.inspect}
ERR
      end
      e
    end

    def md_link(children, ref_id, al = nil)
      md_el(:link, children, {:ref_id => ref_id.downcase}, al)
    end

    def md_im_link(children, url, title = nil, al = nil)
      md_el(:im_link, children, {:url => url, :title => title}, al)
    end

    def md_image(children, ref_id, al = nil)
      md_el(:image, children, {:ref_id => ref_id}, al)
    end

    def md_im_image(children, url, title = nil, al = nil)
      md_el(:im_image, children, {:url => url, :title => title}, al)
    end

    def md_em(children, al = nil)
      md_el(:emphasis, [children].flatten, {}, al)
    end

    def md_br
      md_el(:linebreak, [], {}, nil)
    end

    def md_hrule
      md_el(:hrule, [], {}, nil)
    end

    def md_strong(children, al = nil)
      md_el(:strong, [children].flatten, {}, al)
    end

    def md_emstrong(children, al = nil)
      md_strong(md_em(children), al)
    end

    # A URL to be linkified (e.g. `<http://www.example.com/>`).
    def md_url(url, al = nil)
      md_el(:immediate_link, [], {:url => url}, al)
    end

    # An email to be linkified
    # (e.g. `<andrea@rubyforge.org>` or `<mailto:andrea@rubyforge.org>`).
    def md_email(email, al = nil)
      md_el(:email_address, [], {:email => email}, al)
    end

    def md_entity(entity_name, al = nil)
      md_el(:entity, [], {:entity_name => entity_name}, al)
    end

    # Markdown extra
    def md_foot_ref(ref_id, al = nil)
      md_el(:footnote_reference, [], {:footnote_id => ref_id}, al)
    end

    def md_par(children, al = nil)
      md_el(:paragraph, children, meta = {}, al)
    end

    # A definition of a reference (e.g. `[1]: http://url [properties]`).
    def md_ref_def(ref_id, url, title = nil, meta = {}, al = nil)
      meta[:url] = url
      meta[:ref_id] = ref_id
      meta[:title] = title if title
      md_el(:ref_definition, [], meta, al)
    end

    # inline attribute list
    def md_ial(al)
      al = Maruku::AttributeList.new(al) unless al.is_a?(Maruku::AttributeList)
      md_el(:ial, [], :ial => al)
    end

    # Attribute list definition
    def md_ald(id, al)
      md_el(:ald, [], :ald_id => id, :ald => al)
    end

    # A server directive (e.g. `<?target code... ?>`)
    def md_xml_instr(target, code)
      md_el(:xml_instr, [], :target => target, :code => code)
    end
  end

  class MDElement
    INSPECT2_FORMS = {
      :paragraph          => ["par",      :children],
      :footnote_reference => ["foot_ref", :footnote_id],
      :entity             => ["entity",   :entity_name],
      :email_address      => ["email",    :email],
      :inline_code        => ["code",     :raw_code],
      :raw_html           => ["html",     :raw_html],
      :emphasis           => ["em",       :children],
      :strong             => ["strong",   :children],
      :immediate_link     => ["url",      :url],
      :image              => ["image",    :children, :ref_id],
      :im_image           => ["im_image", :children, :url, :title],
      :link               => ["link",     :children, :ref_id],
      :im_link            => ["im_link",  :children, :url, :title],
      :ref_definition     => ["ref_def",  :ref_id, :url, :title],
      :ial                => ["ial",      :ial]
    }

    # Outputs the abbreviated form of an element
    # (this should be `eval`-able to get a copy of the original element).
    def inspect2
      name, *params = INSPECT2_FORMS[@node_type]
      return nil unless name

      params = params.map do |p|
        next children_inspect if p == :children
        send(p).inspect
      end
      params << @al.inspect if @al && !@al.empty?

      "md_#{name}(#{params.join(', ')})"
    end
  end
end
