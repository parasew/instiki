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
    require_dependency 'sanitize'
    include Sanitize
    def mask
      require_dependency 'redcloth'
      redcloth = RedCloth.new(@content, [:hard_breaks] + @content.options[:engine_opts])
      redcloth.filter_html = false
      redcloth.no_span_caps = false  
      html = redcloth.to_html(:textile)
      sanitize_xhtml(html)
    end
  end

  class Markdown < AbstractEngine
    require_dependency 'sanitize'
    include Sanitize
    def mask
      require_dependency 'maruku'
      require_dependency 'maruku/ext/math'
      html = Maruku.new(@content.delete("\r\x01-\x08\x0B\x0C\x0E-\x1F"), {:math_enabled => false}).to_html
      sanitize_xhtml(html.to_ncr)
    end
  end

  class MarkdownMML < AbstractEngine
    require_dependency 'sanitize'
    include Sanitize
    def mask
      require_dependency 'maruku'
      require_dependency 'maruku/ext/math'
#      html = sanitize_rexml(Maruku.new(@content.delete("\r\x01-\x08\x0B\x0C\x0E-\x1F"),
#            {:math_enabled => true, :math_numbered => ['\\[','\\begin{equation}']}).to_html_tree)
      html = sanitize_xhtml(Maruku.new(@content.delete("\r\x01-\x08\x0B\x0C\x0E-\x1F"),
            {:math_enabled => true, :math_numbered => ['\\[','\\begin{equation}']}).to_html.to_ncr)
    end
  end

  class Mixed < AbstractEngine
    require_dependency 'sanitize'
    include Sanitize
    def mask
      require_dependency 'redcloth'
      redcloth = RedCloth.new(@content, @content.options[:engine_opts])
      redcloth.filter_html = false
      redcloth.no_span_caps = false
      html = redcloth.to_html
      sanitize_xhtml(html)
    end
  end

  class RDoc < AbstractEngine
    require_dependency 'sanitize'
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
