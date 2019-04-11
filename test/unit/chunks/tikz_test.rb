#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
require 'chunks/tikz'
require 'nokogiri'

class TikzTest < Test::Unit::TestCase
  include ChunkMatch

if ENV['tikz_server']

  def test_simple_tikzpicture
  match_pattern(Tikz, '\begin{tikzpicture}a\end{tikzpicture}',
    :plain_text => 'a',
    :unmask_text => Regexp.new("<svg xmlns=\"http:\/\/www.w3.org\/2000\/svg\" xmlns:xlink=\"http:\/\/www.w3.org\/1999\/xlink\"" +
    " width=\"343.711pt\" height=\"0pt\" viewBox=\"0 0 343.711 0\" version=\"1.1\">\n<g id=\"surface[0-9]+-1\">\n</g>\n</svg>")
  )
  end

  def test_equation_nowiki
  match_pattern(Tikz, '\begin{tikzpicture}\node[anchor=east] at (-1,-0.5) {$a$};\end{tikzpicture}',
    :plain_text => Regexp.new('\\\node\[anchor=east\] at \(-1,-0\.5\) \{\$a\$\};'),
    :unmask_text => Regexp.new("<svg xmlns=\"http:\/\/www.w3.org\/2000\/svg\" xmlns:xlink=\"http:\/\/www.w3.org\/1999\/xlink\" " +
    "width=\"11.907pt\" height=\"10.931pt\" viewBox=\"0 0 11.907 10.931\" version=\"1.1\">\n<defs>\n<g>\n<symb" +
    "ol overflow=\"visible\" id=\"glyph[0-9]+-0-0\">\n<path style=\"stroke:none;\" d=\"\"\/>\n<\/symbol>\n<symbol overf" +
    "low=\"visible\" id=\"glyph[0-9]+-0-1\">\n<path style=\"stroke:none;\" d=\"M 3.71875 -3.765625 C 3.53125 -4.14062" +
    "5 3.25 -4.40625 2.796875 -4.40625 C 1.640625 -4.40625 0.40625 -2.9375 0.40625 -1.484375 C 0.40625 -0.5468" +
    "75 0.953125 0.109375 1.71875 0.109375 C 1.921875 0.109375 2.421875 0.0625 3.015625 -0.640625 C 3.09375 -0" +
    ".21875 3.453125 0.109375 3.921875 0.109375 C 4.28125 0.109375 4.5 -0.125 4.671875 -0.4375 C 4.828125 -0.7" +
    "96875 4.96875 -1.40625 4.96875 -1.421875 C 4.96875 -1.53125 4.875 -1.53125 4.84375 -1.53125 C 4.75 -1.531" +
    "25 4.734375 -1.484375 4.703125 -1.34375 C 4.53125 -0.703125 4.359375 -0.109375 3.953125 -0.109375 C 3.671" +
    "875 -0.109375 3.65625 -0.375 3.65625 -0.5625 C 3.65625 -0.78125 3.671875 -0.875 3.78125 -1.3125 C 3.89062" +
    "5 -1.71875 3.90625 -1.828125 4 -2.203125 L 4.359375 -3.59375 C 4.421875 -3.875 4.421875 -3.890625 4.42187" +
    "5 -3.9375 C 4.421875 -4.109375 4.3125 -4.203125 4.140625 -4.203125 C 3.890625 -4.203125 3.75 -3.984375 3." +
    "71875 -3.765625 Z M 3.078125 -1.1875 C 3.015625 -1 3.015625 -0.984375 2.875 -0.8125 C 2.4375 -0.265625 2." +
    "03125 -0.109375 1.75 -0.109375 C 1.25 -0.109375 1.109375 -0.65625 1.109375 -1.046875 C 1.109375 -1.546875" +
    " 1.421875 -2.765625 1.65625 -3.234375 C 1.96875 -3.8125 2.40625 -4.1875 2.8125 -4.1875 C 3.453125 -4.1875" +
    " 3.59375 -3.375 3.59375 -3.3125 C 3.59375 -3.25 3.578125 -3.1875 3.5625 -3.140625 Z( M 3.078125 -1.1875)? \"\/>\n<\/symbol>\n<\/g>" +
    "\n<\/defs>\n<g id=\"surface[0-9]+-1\">\n<g style=\"fill:rgb\\(0%,0%,0%\\);fill-opacity:1;\">\n  <use xlink:href=\"#gl" +
    "yph[0-9]+-0-1\" x=\"3.321\" y=\"7.61\"\/>\n<\/g>\n<\/g>\n<\/svg>")
  )
  end
end
end
