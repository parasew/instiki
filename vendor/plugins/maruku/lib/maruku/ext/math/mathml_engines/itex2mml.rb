module MaRuKu
  module Out
    module HTML
      def convert_to_mathml_itex2mml(kind, tex)
        return if $already_warned_itex2mml
        begin
          require 'itextomml'
        rescue LoadError => e
          maruku_error "Could not load package 'itex2mml'.\nPlease install it." unless $already_warned_itex2mml
          $already_warned_itex2mml = true
          return nil
        end
        begin
          require 'instiki_stringsupport'
        rescue LoadError
          require 'itex_stringsupport'
        end

        parser = Itex2MML::Parser.new
        mathml =
          case kind
          when :equation; parser.block_filter(tex)
          when :inline; parser.inline_filter(tex)
          else
            maruku_error "Unknown itex2mml kind: #{kind}"
            return
          end
        d = Nokogiri::XML::Document.parse(mathml.to_utf8)
        return d.root
      rescue Exception => e
        maruku_error "Invalid MathML TeX: \n#{tex.gsub(/^/, 'tex>')}\n\n #{e.inspect}"
        nil
      rescue
        maruku_error "Could not produce MathML TeX: \n#{tex}\n\n #{e.inspect}"
        nil
      end
    end
  end
end
