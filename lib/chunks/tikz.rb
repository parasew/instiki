require 'chunks/chunk'
require 'sanitizer'
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
    response = HTTParty.post(ENV['tikz_server'], body: { tex: tex, type: type })
    if response.code == 200
      return response.body.sub(/<\?xml .*?\?>\n/, '').chop
    else
      return '<div>Could not render Tikz code to SVG.</div>'
    end
  end

end
