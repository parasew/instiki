require 'html5/constants'
require 'html5/filters/base'

module HTML5
  module Filters

    class OptionalTagFilter < Base
      def slider
        previous1 = previous2 = nil
        __getobj__.each do |token|
          yield previous2, previous1, token if previous1 != nil
          previous2 = previous1
          previous1 = token
        end
        yield previous2, previous1, nil
      end

      def each
        slider do |previous, token, nexttok|
          type = token[:type]
          if type == :StartTag
            yield token unless token[:data].empty? and is_optional_start(token[:name], previous, nexttok)
          elsif type == :EndTag
            yield token unless is_optional_end(token[:name], nexttok)
          else
            yield token
          end
        end
      end

      def is_optional_start(tagname, previous, nexttok)
        type = nexttok ? nexttok[:type] : nil
        if tagname == 'html'
          # An html element's start tag may be omitted if the first thing
          # inside the html element is not a space character or a comment.
          return ![:Comment, :SpaceCharacters].include?(type)
        elsif tagname == 'head'
          # A head element's start tag may be omitted if the first thing
          # inside the head element is an element.
          return type == :StartTag
        elsif tagname == 'body'
          # A body element's start tag may be omitted if the first thing
          # inside the body element is not a space character or a comment,
          # except if the first thing inside the body element is a script
          # or style element and the node immediately preceding the body
          # element is a head element whose end tag has been omitted.
          if [:Comment, :SpaceCharacters].include?(type)
            return false
          elsif type == :StartTag
            # XXX: we do not look at the preceding event, so we never omit
            # the body element's start tag if it's followed by a script or
            # a style element.
            return !%w[script style].include?(nexttok[:name])
          else
            return true
          end
        elsif tagname == 'colgroup'
          # A colgroup element's start tag may be omitted if the first thing
          # inside the colgroup element is a col element, and if the element
          # is not immediately preceeded by another colgroup element whose
          # end tag has been omitted.
          if type == :StartTag
            # XXX: we do not look at the preceding event, so instead we never
            # omit the colgroup element's end tag when it is immediately
            # followed by another colgroup element. See is_optional_end.
            return nexttok[:name] == "col"
          else
            return false
          end
        elsif tagname == 'tbody'
          # A tbody element's start tag may be omitted if the first thing
          # inside the tbody element is a tr element, and if the element is
          # not immediately preceeded by a tbody, thead, or tfoot element
          # whose end tag has been omitted.
          if type == :StartTag
            # omit the thead and tfoot elements' end tag when they are
            # immediately followed by a tbody element. See is_optional_end.
            if previous and previous[:type] == :EndTag && %w(tbody thead tfoot).include?(previous[:name])
              return false
            end

            return nexttok[:name] == 'tr'
          else
            return false
          end
        end
        return false
      end

      def is_optional_end(tagname, nexttok)
        type = nexttok ? nexttok[:type] : nil
        if %w[html head body].include?(tagname)
          # An html element's end tag may be omitted if the html element
          # is not immediately followed by a space character or a comment.
          return ![:Comment, :SpaceCharacters].include?(type)
        elsif %w[li optgroup option tr].include?(tagname)
          # A li element's end tag may be omitted if the li element is
          # immediately followed by another li element or if there is
          # no more content in the parent element.
          # An optgroup element's end tag may be omitted if the optgroup
          # element is immediately followed by another optgroup element,
          # or if there is no more content in the parent element.
          # An option element's end tag may be omitted if the option
          # element is immediately followed by another option element,
          # or if there is no more content in the parent element.
          # A tr element's end tag may be omitted if the tr element is
          # immediately followed by another tr element, or if there is
          # no more content in the parent element.
          if type == :StartTag
            return nexttok[:name] == tagname
          else
            return type == :EndTag || type == nil
          end
        elsif %w(dt dd).include?(tagname)
          # A dt element's end tag may be omitted if the dt element is
          # immediately followed by another dt element or a dd element.
          # A dd element's end tag may be omitted if the dd element is
          # immediately followed by another dd element or a dt element,
          # or if there is no more content in the parent element.
          if type == :StartTag
            return %w(dt dd).include?(nexttok[:name])
          elsif tagname == 'dd'
            return type == :EndTag || type == nil
          else
            return false
          end
        elsif tagname == 'p'
          # A p element's end tag may be omitted if the p element is
          # immediately followed by an address, blockquote, dl, fieldset,
          # form, h1, h2, h3, h4, h5, h6, hr, menu, ol, p, pre, table,
          # or ul  element, or if there is no more content in the parent
          # element.
          if type == :StartTag
            return %w(address blockquote dl fieldset form h1 h2 h3 h4 h5
                      h6 hr menu ol p pre table ul).include?(nexttok[:name])
          else
            return type == :EndTag || type == nil
          end
        elsif tagname == 'colgroup'
          # A colgroup element's end tag may be omitted if the colgroup
          # element is not immediately followed by a space character or
          # a comment.
          if [:Comment, :SpaceCharacters].include?(type)
            return false
          elsif type == :StartTag
            # XXX: we also look for an immediately following colgroup
            # element. See is_optional_start.
            return nexttok[:name] != 'colgroup'
          else
            return true
          end
        elsif %w(thead tbody).include? tagname
          # A thead element's end tag may be omitted if the thead element
          # is immediately followed by a tbody or tfoot element.
          # A tbody element's end tag may be omitted if the tbody element
          # is immediately followed by a tbody or tfoot element, or if
          # there is no more content in the parent element.
          # A tfoot element's end tag may be omitted if the tfoot element
          # is immediately followed by a tbody element, or if there is no
          # more content in the parent element.
          # XXX: we never omit the end tag when the following element is
          # a tbody. See is_optional_start.
          if type == :StartTag
            return %w(tbody tfoot).include?(nexttok[:name])
          elsif tagname == 'tbody'
            return (type == :EndTag or type == nil)
          else
            return false
          end
        elsif tagname == 'tfoot'
          # A tfoot element's end tag may be omitted if the tfoot element
          # is immediately followed by a tbody element, or if there is no
          # more content in the parent element.
          # XXX: we never omit the end tag when the following element is
          # a tbody. See is_optional_start.
          if type == :StartTag
            return nexttok[:name] == 'tbody'
          else
            return type == :EndTag || type == nil
          end
        elsif %w(td th).include? tagname
          # A td element's end tag may be omitted if the td element is
          # immediately followed by a td or th element, or if there is
          # no more content in the parent element.
          # A th element's end tag may be omitted if the th element is
          # immediately followed by a td or th element, or if there is
          # no more content in the parent element.
          if type == :StartTag
            return %w(td th).include?(nexttok[:name])
          else
            return type == :EndTag || type == nil
          end
        end
        return false
      end
    end
  end
end
