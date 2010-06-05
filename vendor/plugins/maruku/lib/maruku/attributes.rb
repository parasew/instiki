#   Copyright (C) 2006  Andrea Censi  <andrea (at) rubyforge.org>
#
# This file is part of Maruku.
#
#   Maruku is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   Maruku is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with Maruku; if not, write to the Free Software
#   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA


module MaRuKu
  # This represents a list of attributes specified in the Markdown document
  # that apply to a Markdown-generated tag.
  # What was `{#id .class key="val" ref}` in the Markdown
  # is parsed into `[[:id, 'id'], [:class, 'id'], ['key', 'val'], [:ref, 'ref']]`.
  class AttributeList < Array
    def to_s
      map do |k, v|
        case k
        when :id;    "#" + quote_if_needed(v)
        when :class; "." + quote_if_needed(v)
        when :ref;    quote_if_needed(v)
        else quote_if_needed(k) + "=" + quote_if_needed(v)
        end
      end.join(' ')
    end
    alias to_md to_s

    private

    def quote_if_needed(str)
      return str unless str =~ /[\s'"]/
      str.inspect
    end
  end

  module In::Markdown::SpanLevelParser
    def md_al(s = []); AttributeList.new(s); end

    # @return [AttributeList, nil]
    def read_attribute_list(src, con, break_on_chars)
      separators = break_on_chars + [?=, ?\s, ?\t]
      escaped = Maruku::EscapedCharInQuotes

      al = AttributeList.new
      loop do
        src.consume_whitespace
        break if break_on_chars.include? src.cur_char

        case src.cur_char
        when nil
          maruku_error "Attribute list terminated by EOF:\n #{al.inspect}", src, con
          tell_user "Returning partial attribute list:\n #{al.inspect}"
          break
        when ?=     # error
          src.ignore_char
          maruku_error "In attribute lists, cannot start identifier with `=`."
          tell_user "Ignoring and continuing."
        when ?#     # id definition
          src.ignore_char
          if id = read_quoted_or_unquoted(src, con, escaped, separators)
            al << [:id, id]
          else
            maruku_error 'Could not read `id` attribute.', src, con
            tell_user 'Ignoring bad `id` attribute.'
          end
        when ?.     # class definition
          src.ignore_char
          if klass = read_quoted_or_unquoted(src, con, escaped, separators)
            al << [:class, klass]
          else
            maruku_error 'Could not read `class` attribute.', src, con
            tell_user 'Ignoring bad `class` attribute.'
          end
        else
          unless key = read_quoted_or_unquoted(src, con, escaped, separators)
            maruku_error 'Could not read key or reference.'
            next
          end

          if src.cur_char != ?=
            al << [:ref, key]
            next
          end

          src.ignore_char # skip the =
          if val = read_quoted_or_unquoted(src, con, escaped, separators)
            al << [key, val]
          else
            maruku_error "Could not read value for key #{key.inspect}.", src, con
            tell_user "Ignoring key #{key.inspect}"
          end
        end
      end
      al
    end

    def merge_ial(elements, src, con)
      # Apply each IAL to the element before
      (elements + [nil]).each_cons(3) do |before, e, after|
        next unless ial?(e)

        if before.kind_of? MDElement
          before.al = e.ial
        elsif after.kind_of? MDElement
          after.al = e.ial
        else
          maruku_error <<ERR, src, con
It's unclear which element the attribute list {:#{e.ial.to_md}}
is referring to. The element before is a #{before.class},
the element after is a #{after.class}.
  before: #{before.inspect}
  after: #{after.inspect}
ERR
        end
      end

      unless Globals[:debug_keep_ials]
        elements.delete_if {|x| ial?(x) && x != elements.first}
      end
    end

    private

    def ial?(e)
      e.is_a?(MDElement) && e.node_type == :ial
    end
  end
end
