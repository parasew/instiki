 # Allow the metal piece to run in isolation
require(File.dirname(__FILE__) + "/../../config/environment") unless defined?(Rails)

require 'stringsupport'

class Itex
  def self.call(env)
    if env["PATH_INFO"] =~ /^\/itex/
      [200, {"Content-Type" => "application/xml"}, [response(env)]]
    else
      [404, {"Content-Type" => "text/html"}, ["Not Found"]]
    end
  end
  
  private
  
  def self.response(env)
    @params = Rack::Request.new(env).params
    tex = (@params['tex'] || '').purify
    case @params['display']
      when 'block'
        filter = :block_filter
      when 'inline'
         filter = :inline_filter
      else
         filter = :inline_filter
    end
    return "<math xmlns='http://www.w3.org/1998/Math/MathML' display='" +
        filter.to_s[/(.*?)_filter/] + "'/>" if tex.strip == ''
    estart = "<math xmlns='http://www.w3.org/1998/Math/MathML' display='inline'><merror><mtext>"
    eend = "</mtext></merror></math>"
    begin
      require 'itextomml'
      itex2mml_parser =  Itex2MML::Parser.new
      itex2mml_parser.send(filter, tex).to_utf8
    rescue LoadError
      estart + "Please install the itex2MML Ruby bindings." + eend  
    rescue Itex2MML::Error => e
      estart + e.to_s + eend
    rescue
      estart + "Unknown Error" + eend
    end
  end
end
