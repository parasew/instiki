$: << File.dirname(__FILE__) + "../../libraries"

require 'redcloth'
require 'bluecloth'
require 'rdocsupport'
require 'chunks/chunk'

# The markup engines are Chunks that call the one of RedCloth, BlueCloth
# or RDoc to convert text. This markup occurs when the chunk is required
# to mask itself.
module Engines
  class AbstractEngine < Chunk::Abstract

    # Create a new chunk for the whole content and replace it with its mask.
    def self.apply_to(content)
      new_chunk = self.new(content)
      content.chunks << new_chunk
      content.replace(new_chunk.mask(content))
    end

    def unmask(content) 
      self
    end

    private 

    # Never create engines by constructor - use apply_to instead
    def initialize(text) 
      @text = text 
    end

  end

  class Textile < AbstractEngine
    def mask(content)
      RedCloth.new(text,content.options[:engine_opts]).to_html
    end
  end

  class Markdown < AbstractEngine
    def mask(content)
      BlueCloth.new(text,content.options[:engine_opts]).to_html
    end
  end

  class RDoc < AbstractEngine
    def mask(content)
      RDocSupport::RDocFormatter.new(text).to_html
    end
  end

  MAP = { :textile => Textile, :markdown => Markdown, :rdoc => RDoc }
end
