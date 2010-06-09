 # Allow the metal piece to run in isolation
require(File.dirname(__FILE__) + "/../../config/environment") unless defined?(Rails)

require 'instiki_stringsupport'

class Itex
  def self.call(env)
    if env["PATH_INFO"] =~ /^\/itex/
      [200, {"Content-Type" => "application/xml"}, [response(env)]]
    else
      [404, {"Content-Type" => "text/html"}, ["Not Found"]]
    end
  end
  
  private

  # plugable XML parser; falls back to REXML
  begin
    require 'nokogiri'
    def self.xmlparse(text)
      Nokogiri::XML(text) { |config| config.options = Nokogiri::XML::ParseOptions::STRICT }
    end
  rescue LoadError
    require 'rexml/document'
    def self.xmlparse(text)
      REXML::Document.new(text)
    end
  end

  #error message to return
  def self.error(str)
    "<math xmlns='http://www.w3.org/1998/Math/MathML' display='inline'><merror><mtext>" +
       str + "</mtext></merror></math>"
  end

  # itex2MML parser
  begin
    require 'itextomml'
    def self.parse_itex(tex, filter)
      Itex2MML::Parser.new.send(filter, tex).to_utf8
    end
  rescue LoadError
    def self.parse_itex(tex, filter)
      error("Please install the itex2MML Ruby bindings.")
    end  
  end

  # the actual response
  def self.response(env)
    params = Rack::Request.new(env).params
    tex = (params['tex'] || '').purify.strip
    case params['display']
      when 'block'
        filter = :block_filter
      else
         filter = :inline_filter
    end
    return "<math xmlns='http://www.w3.org/1998/Math/MathML' display='" +
        filter.to_s[/(.*?)_filter/] + "'/>" if tex == ''
    begin
      doc = parse_itex(tex, filter)
      # make sure the result is well-formed, before sending it off
      begin
        xmlparse(doc)
      rescue
        return error("Ill-formed XML.")
      end
      return doc
    rescue Itex2MML::Error => e
      error(e.to_s)
    rescue
      error("Unknown Error")
    end
  end
end
