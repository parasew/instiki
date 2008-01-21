module HTML5
module Sniffer
  # 4.7.4
  def html_or_feed str
    s = str[0, 512] # steps 1, 2
    pos = 0

    while pos < s.length
      case s[pos]
      when ?\t, ?\ , ?\n, ?\r # 0x09, 0x20, 0x0A, 0x0D == tab, space, LF, CR
        pos += 1
      when ?< # 0x3C
        pos += 1
        if s[pos..pos+2] == "!--" # [0x21, 0x2D, 0x2D]
          pos += 3
          until s[pos..pos+2] == "-->" or pos >= s.length
            pos += 1
          end
          pos += 3
        elsif s[pos] == ?! # 0x21
          pos += 1
          until s[pos] == ?> or pos >= s.length # 0x3E
            pos += 1 
          end
          pos += 1
        elsif s[pos] == ?? # 0x3F
          until s[pos..pos+1] == "?>" or pos >= s.length # [0x3F, 0x3E]
            pos +=  1
          end
          pos += 2
        elsif s[pos..pos+2] == "rss"   # [0x72, 0x73, 0x73]
          return "application/rss+xml"
        elsif s[pos..pos+3] == "feed"  # [0x66, 0x65, 0x65, 0x64]
          return "application/atom+xml"
        elsif s[pos..pos+6] == "rdf:RDF" # [0x72, 0x64, 0x66, 0x3A, 0x52, 0x44, 0x46]
          raise NotImplementedError
        end
      else
        break
      end
    end
    "text/html"
  end
end
end
