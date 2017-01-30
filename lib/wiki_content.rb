require 'cgi'
require 'chunks/engines'
require 'chunks/category'
require_dependency 'chunks/include'
require_dependency 'chunks/redirect'
require_dependency 'chunks/wiki_chunk'
require_dependency 'chunks/literal'
require 'chunks/nowiki'
require 'sanitizer'
require 'itex_stringsupport'
require 'set'


# Wiki content is just a string that can process itself with a chain of
# actions. The actions can modify wiki content so that certain parts of
# it are protected from being rendered by later actions.
#
# When wiki content is rendered, it can be interrogated to find out
# which chunks were rendered. This means things like categories, wiki
# links, can be determined.
#
# Exactly how wiki content is rendered is determined by a number of
# settings that are optionally passed in to a constructor. The current
# options are:
#  * :engine
#    => The structural markup engine to use (Textile, Markdown, RDoc)
#  * :engine_opts
#    => A list of options to pass to the markup engines (safe modes, etc)
#  * :pre_engine_actions
#    => A list of render actions or chunks to be processed before the
#       markup engine is applied. By default this is:
#       Category, Include, URIChunk, WikiChunk::Link, WikiChunk::Word
#  * :post_engine_actions
#    => A list of render actions or chunks to apply after the markup
#       engine. By default these are:
#       Literal::Pre, Literal::Tags
#  * :mode
#    => How should the content be rendered? For normal display (show),
#       publishing (:publish) or export (:export)?

module ChunkManager
  attr_reader :chunks_by_type, :chunks_by_id, :chunks, :chunk_id

  ACTIVE_CHUNKS = [ NoWiki, Category, Redirect, WikiChunk::Link,
                    WikiChunk::Word ]

  HIDE_CHUNKS = [ Literal::Pre, Literal::Tags, Literal::Math ]

  MASK_RE = {
    ACTIVE_CHUNKS => Chunk::Abstract.mask_re(ACTIVE_CHUNKS),
    HIDE_CHUNKS => Chunk::Abstract.mask_re(HIDE_CHUNKS)
  }

  def init_chunk_manager
    @chunks_by_type = Hash.new
    Chunk::Abstract::derivatives.each{|chunk_type|
      @chunks_by_type[chunk_type] = Set.new
    }
    @chunks_by_id = Hash.new
    @chunks = Set.new
    @chunk_id = 0
  end

  def add_chunk(c)
    @chunks_by_type[c.class] << c
    @chunks_by_id[c.object_id] = c
    @chunks << c
    @chunk_id += 1
  end

  def delete_chunk(c)
    @chunks_by_type[c.class].delete(c)
    @chunks_by_id.delete(c.object_id)
    @chunks.delete(c)
  end

  def merge_chunks(other)
    other.chunks.each{|c| add_chunk(c)}
  end

  def scan_chunkid(text)
    text.scan(MASK_RE[ACTIVE_CHUNKS]){|a| yield a[0] }
  end

  def find_chunks(chunk_type)
    @chunks.select { |chunk| chunk.kind_of?(chunk_type) and chunk.rendered? }
  end

end

# A simplified version of WikiContent. Useful to avoid recursion problems in
# WikiContent.new
class WikiContentStub < String

  attr_reader :web, :options
  include ChunkManager

  def initialize(content, web, options)
    super(content)
    @web = web
    @options = options
    init_chunk_manager
  end

  # Detects the mask strings contained in the text of chunks of type chunk_types
  # and yields the corresponding chunk ids
  # example: content = "chunk123categorychunk <pre>chunk456categorychunk</pre>"
  # inside_chunks(Literal::Pre) ==> yield 456
  def inside_chunks(chunk_types)
    chunk_types.each{|chunk_type|  chunk_type.apply_to(self) }

    chunk_types.each{|chunk_type| @chunks_by_type[chunk_type].each{|hide_chunk|
        scan_chunkid(hide_chunk.text){|id| yield id }
      }
    }
  end
end

class WikiContent < ActiveSupport::SafeBuffer

  include ChunkManager
  include Sanitizer

  DEFAULT_OPTS = {
    :active_chunks       => ACTIVE_CHUNKS,
    :hide_chunks         => HIDE_CHUNKS,
    :engine              => Engines::MarkdownMML,
    :engine_opts         => [],
    :mode                => :show
  }.freeze

  attr_reader :web, :options, :revision, :not_rendered, :pre_rendered, :url_generator

  # Create a new wiki content string from the given one.
  # The options are explained at the top of this file.
  def initialize(revision, url_generator, options = {})
    @revision = revision
    @url_generator = url_generator
    @web = @revision.page.web

    @options = DEFAULT_OPTS.dup.merge(options)
    @options[:engine] = Engines::MAP[@web.markup]
    @options[:engine_opts] = [:filter_html, :filter_styles] if @web.safe_mode?
    @options[:active_chunks] = (ACTIVE_CHUNKS - [WikiChunk::Word] ) if @web.brackets_only?
    @options[:hide_chunks] = (HIDE_CHUNKS - [Literal::Math] ) unless
                  [Engines::MarkdownMML, Engines::MarkdownPNG].include?(@options[:engine])
    if @options[:engine] == Engines::MarkdownPNG
      @options[:png_url] =
         @options[:mode] == :export ? 'files/pngs/' :
           (@url_generator.url_for :controller => 'file', :web => @web.address,
             :action => 'file', :id => 'pngs', :only_path => true) + '/'
    end

    @not_rendered = @pre_rendered = nil

    super(@revision.content)
    init_chunk_manager
    build_chunks
    @not_rendered = String.new(self)
  end

  # Call @web.page_link using current options.
  def page_link(web_name, name, anchor_name, text=nil, link_type)
    web = Web.find_by_name(web_name) || Web.find_by_address(web_name) || @web
    @options[:link_type] = (link_type || :show)
    @url_generator.make_link(@web, name, anchor_name, web, text, @options)
  end

  def build_chunks
    # create and mask Includes and "active_chunks" chunks
    NoWiki.apply_to(self) if @options[:active_chunks].include?(NoWiki)
    Include.apply_to(self)
    @options[:active_chunks].each{|chunk_type| chunk_type.apply_to(self) unless chunk_type == NoWiki}

    # Handle hiding contexts like "pre" and "code" etc..
    # The markup (textile, rdoc etc) can produce such contexts with its own syntax.
    # To reveal them, we work on a copy of the content.
    # The copy is rendered and used to detect the chunks that are inside protecting context
    # These chunks are reverted on the original content string.

    copy = WikiContentStub.new(self, @web, @options)
    @options[:engine].apply_to(copy)

    copy.inside_chunks(@options[:hide_chunks]) do |id|
      @chunks_by_id[id.to_i].revert if @chunks_by_id[id.to_i]
    end
  end

  def delete_chunks!(types)
    types.each do |t|
      @chunks_by_type[t].each do |c|
        @pre_rendered.sub!(c.mask, '') if @pre_rendered
        @chunks.delete(c)
      end
    end
    self
  end

  def pre_render!
    unless @pre_rendered
      @chunks_by_type[Include].each{|chunk| chunk.unmask }
      @pre_rendered = String.new(self)
    end
    @pre_rendered
  end

  def render!
    pre_render!
    @options[:engine].apply_to(self)
    as_utf8
    # unmask in one go. $~[1] is the chunk id
    text = self.to_str
    text.gsub!(MASK_RE[ACTIVE_CHUNKS]) do
      chunk = @chunks_by_id[$~[1].to_i]
      if chunk.nil?
        # if we match a chunkmask that existed in the original content string
        # just keep it as it is
        $~[0]
      else
        chunk.unmask_text
      end
    end
    self.replace xhtml_sanitize(text)
    @dirty = false # Instance variable from ActiveSupport::SafeBuffer, so we
                   # are self-marking this instance as HTML-safe

    self
  end

  def page_name
    @revision.page.name
  end

end

