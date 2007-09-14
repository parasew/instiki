$: << File.dirname(__FILE__) + "../../lib"

require_dependency 'chunks/chunk'

# The markup engines are Chunks that call the one of RedCloth
# or RDoc to convert text. This markup occurs when the chunk is required
# to mask itself.
module Engines
  class AbstractEngine < Chunk::Abstract

    # Create a new chunk for the whole content and replace it with its mask.
    def self.apply_to(content)
      new_chunk = self.new(content)
      content.replace(new_chunk.mask)
    end

    private 

    # Never create engines by constructor - use apply_to instead
    def initialize(content) 
      @content = content
    end

  end

  class Textile < AbstractEngine
    require 'sanitize'
    include Sanitize
    def mask
      require 'redcloth'
      redcloth = RedCloth.new(@content, [:hard_breaks] + @content.options[:engine_opts])
      redcloth.filter_html = false
      redcloth.no_span_caps = false  
      html = redcloth.to_html(:textile)
      sanitize_xhtml(html)
    end
  end

  class Markdown < AbstractEngine
    require 'sanitize'
    include Sanitize
    def mask
      require 'maruku'
      require 'maruku/ext/math'

      # If the request is for S5, call Maruku accordingly (without math)
      if @content.options[:mode] == :s5
        my_content = Maruku.new(@content.delete("\r"), {:math_enabled => false,
                            :content_only => true,
                            :author => @content.options[:engine_opts][:author],
                            :title => @content.options[:engine_opts][:title]})
        @content.options[:renderer].s5_theme = my_content.s5_theme
        sanitize_xhtml(my_content.to_s5)
      else
        sanitize_rexml(Maruku.new(@content.delete("\r"),
                           {:math_enabled => false}).to_html_tree)
      end

    end
  end

  class MarkdownMML < AbstractEngine
    require 'sanitize'
    include Sanitize
    def mask
      require 'maruku'
      require 'maruku/ext/math'

      # If the request is for S5, call Maruku accordingly
      if @content.options[:mode] == :s5
        my_content = Maruku.new(@content.delete("\r"), {:math_enabled => true,
                            :math_numbered => ['\\[','\\begin{equation}'],
                            :content_only => true,
                            :author => @content.options[:engine_opts][:author],
                            :title => @content.options[:engine_opts][:title]})
        @content.options[:renderer].s5_theme = my_content.s5_theme
        sanitize_xhtml(my_content.to_s5)
      else
        html = sanitize_rexml(Maruku.new(@content.delete("\r"),
             {:math_enabled => true,
              :math_numbered => ['\\[','\\begin{equation}']}).to_html_tree)
        html.gsub(/\A<div class="maruku_wrapper_div">\n?(.*?)\n?<\/div>\Z/m, '\1')
      end

    end
  end

  class Mixed < AbstractEngine
    require 'sanitize'
    include Sanitize
    def mask
      require 'redcloth'
      redcloth = RedCloth.new(@content, @content.options[:engine_opts])
      redcloth.filter_html = false
      redcloth.no_span_caps = false
      html = redcloth.to_html
      sanitize_xhtml(html)
    end
  end

  class RDoc < AbstractEngine
    require 'sanitize'
    include Sanitize
    def mask
      require_dependency 'rdocsupport'
      html = RDocSupport::RDocFormatter.new(@content).to_html
      sanitize_xhtml(html)
    end
  end

  MAP = { :textile => Textile, :markdown => Markdown, :markdownMML => MarkdownMML, :mixed => Mixed, :rdoc => RDoc }
  MAP.default = Textile
end
