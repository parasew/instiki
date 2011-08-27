# This module groups all functions related to HTML export.
module MaRuKu

require 'nokogiri'
require 'maruku/string_utils'
	 
	class MDDocument

	def s5_theme
	  html_escape(self.attributes[:slide_theme] || "default")
	end
		
	# Render as an HTML fragment (no head, just the content of BODY). (returns a string)
	def to_s5(context={})
		indent       = context[:indent]       || -1
		ie_hack      = !context[:ie_hack].kind_of?(FalseClass)
		content_only = !context[:content_only].kind_of?(FalseClass)

		doc = Nokogiri::XML::Document.new

		if content_only
			body = Nokogiri::XML::Element.new('div', doc)
		else
			html = Nokogiri::XML::Element.new('html', doc)
			doc << html
			html.add_namespace(nil, 'http://www.w3.org/1999/xhtml')
			html.add_namespace('svg', "http://www.w3.org/2000/svg" )

			head = Nokogiri::XML::Element.new('head', html)
			html << head
			me = Nokogiri::XML::Element.new('meta', head)
			me['http-equiv'] = 'Content-type'
			me['content'] = 'text/html;charset=utf-8'
			head << meta

			# Create title element
			doc_title = self.attributes[:title] || self.attributes[:subject] || ""
			title = Nokogiri::XML::Element.new 'title', head
				title << Nokogiri::XML::Text.new(doc_title, head)
            head << title		
			body = Nokogiri::XML::Element.new('body', html)
			html << body
			
		end
		
		slide_header = self.attributes[:slide_header]
		slide_footer = self.attributes[:slide_footer]
		slide_subfooter = self.attributes[:slide_subfooter]
		slide_topleft  = self.attributes[:slide_topleft]
		slide_topright  = self.attributes[:slide_topright]
		slide_bottomleft  = self.attributes[:slide_bottomleft]
		slide_bottomright  = self.attributes[:slide_bottomright]

		dummy_layout_slide = 
		"
		<div class='layout'>
		<div id='controls'> </div>
		<div id='currentSlide'> </div>
		<div id='header'> #{slide_header}</div>
		<div id='footer'>
		<h1>#{slide_footer}</h1>
		<h2>#{slide_subfooter}</h2>
		</div>
		<div class='topleft'> #{slide_topleft}</div>
		<div class='topright'> #{slide_topright}</div>
		<div class='bottomleft'> #{slide_bottomleft}</div>
		<div class='bottomright'> #{slide_bottomright}</div>
		</div>
                "
		body <<  Nokogiri::XML::Document.parse(dummy_layout_slide).root

		presentation = Nokogiri::XML::Element.new('div', body)
		presentation['class'] = 'presentation'
		body << presentation
		
		first_slide="
	  <div class='slide'>
	  <h1> #{self.attributes[:title] ||context[:title]}</h1>
	  <h2> #{self.attributes[:subtitle] ||context[:subtitle]}</h2>
	  <h3> #{self.attributes[:author] ||context[:author]}</h3>
	  <h4> #{self.attributes[:company] ||context[:company]}</h4>
	  </div>
		"
		presentation << Nokogiri::XML::Document.parse(first_slide).root

		slide_num = 0
		self.toc.section_children.each do |slide|
			slide_num += 1
			@doc.attributes[:doc_prefix] = "s#{slide_num}"
			
#			puts "Slide #{slide_num}: " + slide.header_element.to_s
			div = Nokogiri::XML::Element.new('div', presentation)
			presentation << div
			div['class'] = 'slide'
			
			h1 = Nokogiri::XML::Element.new('h1', div)
			slide.header_element.children_to_html.each do |e| h1 << e; end
			div << h1
			
			array_to_html(slide.immediate_children).each do |e|  div << e  end
				
			# render footnotes
			if @doc.footnotes_order.size > 0
				div << render_footnotes
				@doc.footnotes_order = []
			end
		end

		if (content_only)
		  xml = body.to_xml(:indent => (context[:indent] || 2), :save_with => 18 )
		else
		  doc2 = Nokogiri::XML::Document.parse("<div>"+S5_external+"</div>")
		  doc2.root.children.each{ |child| head << child }

		  add_css_to(head)

		  xml = html.to_xml(:indent => (context[:indent] || 2), :save_with => 18 )
		  Xhtml11_mathml2_svg11 + xml
		end
	end

end 


end
