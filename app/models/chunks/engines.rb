$: << File.dirname(__FILE__) + "../../lib"

require 'redcloth'
require 'bluecloth_tweaked'
require 'rdocsupport'
require 'chunks/chunk'

# The markup engines are Chunks that call the one of RedCloth
# or RDoc to convert text. This markup occurs when the chunk is required
# to mask itself.
module Engines
  class AbstractEngine

    # Convert content to HTML
    def self.apply_to(content)
      engine = self.new(content)
      content.replace(engine.to_html)
    end

    private 

    # Never create engines by constructor - use apply_to instead
    def initialize(content) 
      @content = content
    end

  end

  class Textile < AbstractEngine
    def to_html
      redcloth = RedCloth.new(@content, [:hard_breaks] + @content.options[:engine_opts])
      redcloth.filter_html = false
      redcloth.no_span_caps = false  
      redcloth.to_html(:textile)
    end
  end

  class Markdown < AbstractEngine
    def to_html
      BlueCloth.new(@content, @content.options[:engine_opts]).to_html
    end
  end

  class Mixed < AbstractEngine
    def to_html
      redcloth = RedCloth.new(@content, @content.options[:engine_opts])
      redcloth.filter_html = false
      redcloth.no_span_caps = false
      redcloth.to_html
    end
  end

  class RDoc < AbstractEngine
    def to_html
      RDocSupport::RDocFormatter.new(@content).to_html
    end
  end

  MAP = { :textile => Textile, :markdown => Markdown, :mixed => Mixed, :rdoc => RDoc }
  MAP.default = Textile
end
