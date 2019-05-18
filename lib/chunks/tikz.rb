require 'chunks/chunk'
require 'httparty'

# This chunks support tikzpicture and tikzcd environments
# It relies on an external service to render the tikzcode into SVG.
# Created: 24th Feb 2019

class Tikz < Chunk::Abstract

  TIKZ_PATTERN = Regexp.new('\\\begin\{(tikzpicture|tikzcd)\}(.*?)\\\end\{(tikzpicture|tikzcd)\}', Regexp::MULTILINE)
  def self.pattern() TIKZ_PATTERN end

  attr_reader :plain_text, :unmask_text

  def initialize(match_data, content)
    super
    @plain_text = match_data[2]
    @unmask_text = get_svg(match_data[2], match_data[1])
  end

  private

  def get_svg(tex, type)
    begin
      response = HTTParty.post(ENV['tikz_server'], body: { tex: tex, type: type }, timeout: 4)
      if response.code == 200
        svg = response.body.sub(/<\?xml .*?\?>\n/, '').chop
        # since the page may contain multiple tikz pictures, we need to make the glyph id's unique
        num = rand(10000)
        return svg.gsub(/(id=\"|xlink:href=\"#)glyph/, "\\1glyph#{num}-").gsub(/id=\"surface/, "id=\"surface#{num}-").gsub(/(id=\"|url\(#)clip/, "\\1clip#{num}-")
      else
        return '<div>Could not render Tikz code to SVG.</div>'
      end
    rescue Net::ReadTimeout => exception
      return '<div>The Tikz Server timed out or was unreachable.</div>'
    end
  end

end
