=begin maruku_doc
Extension: math
Attribute: html_math_engine
Scope: document, element
Output: html
Summary: Select the rendering engine for MathML.
Default: <?mrk Globals[:html_math_engine].to_s ?>

Select the rendering engine for math.

If you want to use your custom engine `foo`, then set:

  HTML math engine: foo
{:lang=markdown}

and then implement two functions:

  def convert_to_mathml_foo(kind, tex)
    ...
  end
=end

=begin maruku_doc
Extension: math
Attribute: html_png_engine
Scope: document, element
Output: html
Summary: Select the rendering engine for math.
Default: <?mrk Globals[:html_math_engine].to_s ?>

Same thing as `html_math_engine`, only for PNG output.

  def convert_to_png_foo(kind, tex)
    # same thing
    ...
  end
{:lang=ruby}

=end

require 'nokogiri'

module MaRuKu
  module Out
    module HTML
      # Creates an xml Mathml document of this node's TeX code.
      #
      # @return Nokogiri::XML::Document]
      def render_mathml(kind, tex)
        engine = get_setting(:html_math_engine)
        method = "convert_to_mathml_#{engine}"
        if self.respond_to? method
          mathml = self.send(method, kind, tex)
          return mathml || convert_to_mathml_none(kind, tex)
        end

        # TODO: Warn here
        puts "A method called #{method} should be defined."
        return convert_to_mathml_none(kind, tex)
      end

      # Renders a PNG image of this node's TeX code.
      # Returns
      #
      # @return [MaRuKu::Out::HTML::PNG, nil]
      #   A struct describing the location and size of the image,
      #   or nil if no library is loaded that can render PNGs.
      def render_png(kind, tex)
        engine = get_setting(:html_png_engine)
        method = "convert_to_png_#{engine}".to_sym
        return self.send(method, kind, tex) if self.respond_to? method

        puts "A method called #{method} should be defined."
        return nil
      end

      def pixels_per_ex
        $pixels_per_ex ||= render_png(:inline, "x").height
      end

      def adjust_png(png, use_depth)
	    d = Nokogiri::XML::Document.new
        src = png.src

        height_in_px = png.height
        depth_in_px = png.depth
        height_in_ex = height_in_px / pixels_per_ex
        depth_in_ex = depth_in_px / pixels_per_ex
        total_height_in_ex = height_in_ex + depth_in_ex
        style = ""
        style << "vertical-align: -#{depth_in_ex}ex;" if use_depth
        style << "height: #{total_height_in_ex}ex;"

        img = Nokogiri::XML::Element.new('img', d)
        img['src'] = src
        img['style'] = style
        img['alt'] = "$#{self.math.strip}$"
        img
      end

      def to_html_inline_math
	    d = Nokogiri::XML::Document.new
        mathml = get_setting(:html_math_output_mathml) && render_mathml(:inline, self.math)
        png    = get_setting(:html_math_output_png)    && render_png(:inline, self.math)

        span = create_html_element 'span'
        span['class'] = 'maruku-inline'

        if mathml
          mathml['class'] = 'maruku-mathml'
          return mathml
        end

        if png
          img = adjust_png(png, true)
          add_class_to(img, 'maruku-png')
          span << img
        end

        span
      end

      def to_html_equation
        d = Nokogiri::XML::Document.new
        mathml = get_setting(:html_math_output_mathml) && render_mathml(:equation, self.math)
        png    = get_setting(:html_math_output_png)    && render_png(:equation, self.math)

        div = create_html_element 'div'
        div['class'] = 'maruku-equation'
        if mathml
          if self.label  # then numerate
            span = Nokogiri::XML::Element.new('span', d)
            span['class'] = 'maruku-eq-number'
            span << Nokogiri::XML::Text.new("(#{self.num})", d)
            div << span
            div['id'] = "eq:#{self.label}"
          end	
          add_class_to(mathml, 'maruku-mathml')
          div << mathml
        end

        if png
          img = adjust_png(png, false)
          add_class_to(img, 'maruku-png')
          div << img
          if self.label  # then numerate
            span = Nokogiri::XML::Element.new('span', d)
            span['class'] = 'maruku-eq-number'
            span << Nokogiri::XML::Text.new("(#{self.num})", d)
            div << span
            div['id'] = "eq:#{self.label}"
          end	
        end

        source_span = Nokogiri::XML::Element.new('span', d)
        add_class_to(source_span, 'maruku-eq-tex')
        code = convert_to_mathml_none(:equation, self.math.strip)
        code['style'] = 'display: none'
        source_span << code
        div << source_span

        div
      end

      def to_html_eqref
        d = Nokogiri::XML::Document.new
        unless eq = self.doc.eqid2eq[self.eqid]
          maruku_error "Cannot find equation #{self.eqid.inspect}"
          return Nokogiri::XML::Text.new("(eq:#{self.eqid})", d)
        end

        a = Nokogiri::XML::Element.new('a', d)
        a['class'] = 'maruku-eqref'
        a['href'] = "#eq:#{self.eqid}"
        a << Nokogiri::XML::Text.new("(#{eq.num})", d)
        a
      end

      def to_html_divref
        d = Nokogiri::XML::Document.new
        unless hash = self.doc.refid2ref.values.find {|h| h.has_key?(self.refid)}
          maruku_error "Cannot find div #{self.refid.inspect}"
          return Nokogiri::XML::Text.new("\\ref{#{self.refid}}", d)
        end
        ref= hash[self.refid]

        a = Nokogiri::XML::Element.new('a', d)
        a['class'] = 'maruku-ref'
        a['href'] = "#" + self.refid
        a << Nokogiri::XML::Text.new(ref.num.to_s, d)
        a
      end
    end
  end
end
